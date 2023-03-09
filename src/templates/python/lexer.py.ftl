[#ftl strict_vars=true]
# Parser lexing package. Generated by ${generated_by}. Do not edit.
[#import "common_utils.inc.ftl" as CU]

import bisect
from enum import Enum, auto, unique
import logging
import re

from .tokens import (TokenType, LexicalState, InvalidToken, IgnoredToken,
                     SkippedToken, new_token)

[#if settings.extraTokens?size > 0]
  [#list settings.extraTokenNames as tokenName]
from .tokens import ${settings.extraTokens[tokenName]}
  [/#list]
[/#if]
from .utils import as_chr, _List, EMPTY_SET, HashSet

# See if an accelerated BitSet is available.
try:
    from _bitset import BitSet
    _fast_bitset = True
except ImportError:
    from .utils import BitSet
    _fast_bitset = False

${globals.translateLexerImports()}

[#var NFA_RANGE_THRESHOLD = 16]
[#var MAX_INT=2147483647]
[#var lexerData=grammar.lexerData]
[#var multipleLexicalStates = lexerData.lexicalStates.size() > 1]
[#var TT = "TokenType."]

logger = logging.getLogger(__name__)

DEFAULT_TAB_SIZE = ${settings.tabSize}

#
# Hack to allow token types to be referenced in snippets without
# qualifying
#
globals().update(TokenType.__members__)

# NFA code and data
[#if multipleLexicalStates]
# A mapping from lexical state to NFA functions for that state.
[#-- We only need the mapping if there is more than one lexical state.--]
function_table_map = {}
[/#if]

[#list lexerData.lexicalStates as lexicalState]
[@GenerateStateCode lexicalState/]
[/#list]

# Just use binary search to check whether the char is in one of the
# intervals
def check_intervals(ranges, ch):
    index = bisect.bisect_left(ranges, ch)
    n = len(ranges)
    if index < n:
        if index % 2 == 0:
            if index < (n - 1):
                return ranges[index] <= ch <= ranges[index + 1]
        elif index > 0:
            return ranges[index - 1] <= ch <= ranges[index]
    return False

[#--
  Generate all the NFA transition code
  for the given lexical state
--]
[#macro GenerateStateCode lexicalState]
[#list lexicalState.allNfaStates as nfaState]
[#if nfaState.moveRanges.size() >= NFA_RANGE_THRESHOLD]
[@GenerateMoveArray nfaState/]
[/#if]
[/#list]

[#list lexicalState.canonicalSets as state]
[@GenerateNfaStateMethod state/]
[/#list]

def NFA_FUNCTIONS_${lexicalState.name}_init():
    functions = [
[#list lexicalState.canonicalSets as state]
        ${state.methodName}[#if state_has_next],[/#if]
[/#list]
    ]
[#if multipleLexicalStates]
    function_table_map[LexicalState.${lexicalState.name}] = functions
[#else]
    return functions
[/#if]

[#if multipleLexicalStates]
NFA_FUNCTIONS_${lexicalState.name}_init()
[#else]
nfa_functions = NFA_FUNCTIONS_${lexicalState.name}_init()
[/#if]

[/#macro]

[#--
   Generate the array representing the characters
   that this NfaState "accepts".
   This corresponds to the moveRanges field in
   org.congocc.core.NfaState
--]
[#macro GenerateMoveArray nfaState]
[#var moveRanges = nfaState.moveRanges]
[#var arrayName = nfaState.movesArrayName]
${arrayName} = [
[#list nfaState.moveRanges as char]
    ${globals.displayChar(char)}[#if char_has_next],[/#if]
[/#list]
]
[/#macro]

[#--
   Generate the method that represents the transitions
   that correspond to an instanceof org.congocc.core.CompositeStateSet
--]
[#macro GenerateNfaStateMethod nfaState]
def ${nfaState.methodName}(ch, next_states, valid_types):
    [#var states = nfaState.orderedStates]
    [#-- sometimes set in the code below --]
    type = None
    [#var useElif = false]
    [#list states as state]
      [#var isFirstOfGroup=true, isLastOfGroup=true]
      [#if state_index!=0]
         [#set isFirstOfGroup = !states[state_index-1].moveRanges.equals(state.moveRanges)]
      [/#if]
      [#if state_has_next]
         [#set isLastOfGroup = !states[state_index+1].moveRanges.equals(state.moveRanges)]
      [/#if]
      [@GenerateStateMove state isFirstOfGroup isLastOfGroup useElif /]
      [#if state_has_next && isLastOfGroup && !states[state_index+1].overlaps(states.subList(0, state_index+1))]
        [#set useElif = true]
      [#else]
        [#set useElif = false]
      [/#if]
    [/#list]
    return type
[/#macro]

[#--
  Generates the code for an NFA state transition
  within a composite state. This code is a bit tricky
  because it consolidates more than one condition in
  a single conditional block.
--]
[#macro GenerateStateMove nfaState isFirstOfGroup isLastOfGroup useElif=false]
  [#var nextState = nfaState.nextState.composite]
  [#var type = nfaState.nextState.type]
    [#if isFirstOfGroup]
    [#if useElif]elif[#else]if[/#if] [@NfaStateCondition nfaState /]:
    [/#if]
      [#if nextState.index >= 0]
        next_states.set(${nextState.index})
      [/#if]
   [#if isLastOfGroup]
      [#if type??]
        if ${TT}${type.label} in valid_types:
            type = ${TT}${type.label}
     [/#if]
   [/#if]
[/#macro]

[#--
Generate the condition part of the NFA state transition
If the size of the moveRanges vector is greater than NFA_RANGE_THRESHOLD
it uses the canned binary search routine. For the smaller moveRanges
it just generates the inline conditional expression
--]
[#macro NfaStateCondition nfaState]
    [#if nfaState.moveRanges?size < NFA_RANGE_THRESHOLD]
      [@RangesCondition nfaState.moveRanges /][#t]
    [#elseif nfaState.hasAsciiMoves && nfaState.hasNonAsciiMoves]
      ([@RangesCondition nfaState.asciiMoveRanges/]) or (ch >= chr(128) and check_intervals(${nfaState.movesArrayName}, ch))[#t]
    [#else]
      check_intervals(${nfaState.movesArrayName}, ch)[#t]
    [/#if]
[/#macro]

[#--
This is a recursive macro that generates the code corresponding
to the accepting condition for an NFA state. It is used
if NFA state's moveRanges array is smaller than NFA_RANGE_THRESHOLD
(which is set to 16 for now)
--]
[#macro RangesCondition moveRanges]
    [#var left = moveRanges[0], right = moveRanges[1]]
    [#var displayLeft = globals.displayChar(left), displayRight = globals.displayChar(right)]
    [#var singleChar = left == right]
    [#if moveRanges?size==2]
       [#if singleChar]
          ch == ${displayLeft}[#t]
       [#elseif left +1 == right]
          ch == ${displayLeft} or ch == ${displayRight}[#t]
       [#elseif left > 0]
          ch >= ${displayLeft}[#t]
          [#if right < 1114111]
 and ch <= ${displayRight}[#rt]
          [/#if]
       [#else]
           ch <= ${displayRight}[#t]
       [/#if]
    [#else]
       ([@RangesCondition moveRanges[0..1]/]) or ([@RangesCondition moveRanges[2..moveRanges?size-1]/])[#t]
    [/#if]
[/#macro]

# Compute the maximum size of state bitsets

[#if !multipleLexicalStates]
MAX_STATES = ${lexerData.lexicalStates.get(0).allNfaStates.size()}
[#else]
MAX_STATES = max(
[#list lexerData.lexicalStates as state]
    ${state.allNfaStates.size()}[#if state_has_next],[/#if]
[/#list]
)
[/#if]

# Lexer code and data

[#macro EnumSet varName tokenNames indent=0]
[#var is = ""?right_pad(indent)]
[#if tokenNames?size=0]
${is}self.${varName} = EMPTY_SET
[#else]
${is}self.${varName} = {
   [#list tokenNames as type]
${is}    TokenType.${type}[#if type_has_next],[/#if]
   [/#list]
${is}}
[/#if]
[/#macro]

[#if multipleLexicalStates]
# A mapping for lexical state transitions triggered by a certain token type (token type -> lexical state)
token_type_to_lexical_state_map = {}
[/#if]

def get_function_table_map(lexical_state):
    [#if multipleLexicalStates]
    return function_table_map[lexical_state]
    [#else]
    # We only have one lexical state in this case, so we return that!
    return nfa_functions
    [/#if]

[#var PRESERVE_LINE_ENDINGS=settings.preserveLineEndings?string("True", "False")
      JAVA_UNICODE_ESCAPE= settings.javaUnicodeEscape?string("True", "False")
      ENSURE_FINAL_EOL = settings.ensureFinalEOL?string("True", "False")
      TERMINATING_STRING = "\"" + settings.terminatingString?j_string + "\""
      PRESERVE_TABS = settings.preserveTabs?string("True", "False")
]

CODING_PATTERN = re.compile(rb'^[ \t\f]*#.*coding[:=][ \t]*([-_.a-zA-Z0-9]+)')

def _input_text(input_source):
    # Check if it's an existing filename
    try:
        with open(input_source, 'rb') as f:
            text = f.read()
    except OSError:
        return input_source  # assume it's source rather than a path to source
    implicit = False
    if len(text) <= 3:
        encoding = 'utf-8'
        implicit = True
    elif text[:3] == b'\xEF\xBB\xBF':
        text = text[3:]
        encoding = 'utf-8'
    elif text[:2] == b'\xFF\xFE':
        text = text[2:]
        encoding = 'utf-16le'
    elif text[:2] == b'\xFE\xFF':
        text = text[2:]
        encoding = 'utf-16be'
    elif text[:4] == b'\xFF\xFE\x00\x00':
        text = text[4:]
        encoding = 'utf-32le'
    elif text[:4] == b'\x00\x00\xFE\xFF':
        text = text[4:]
        encoding = 'utf-32be'
    else:
        # No encoding from BOM.
        encoding = 'utf-8'
        implicit = True
        if input_source.endswith(('.py', '.pyw')):
            # Look for coding in first two lines
            parts = text.split(b'\n', 2)
            m = CODING_PATTERN.match(parts[0])
            if not m and len(parts) > 1:
                m = CODING_PATTERN.match(parts[1])
            if m:
                encoding = m.groups()[0].decode('ascii')
    try:
        return text.decode(encoding, errors='replace')
    except UnicodeDecodeError:
        if not implicit:
            raise
        return text.decode('latin-1')

[#-- #var lexerClassName = settings.lexerClassName --]
[#var lexerClassName = "Lexer"]
class ${lexerClassName}:

    __slots__ = (
        'input_source',
        'tab_size',
[#if settings.lexerUsesParser]
        'parser',
[/#if]
        'next_states',
        'current_states',
        '_char_buf',
        'active_token_types',
        'pending_invalid_chars',
        'starting_line',
        'starting_column',
        'invalid_token',
        'previous_token',
        'regular_tokens',
        'unparsed_tokens',
        'skipped_tokens',
        'more_tokens',
        'lexical_state',
        '_line_offsets',
        '_need_to_calculate_columns',
        '_token_offsets',
        '_token_location_table',
        'content',
        'content_len',
        '_buffer_position',
        '_dummy_start_token',
        '_ignored',
        '_skipped',
[#var injectedFields = globals.injectedLexerFieldNames()]
[#if injectedFields?size > 0]
        # injected fields
[#list injectedFields as fieldName]
        '${fieldName}',
[/#list]
[/#if]
    )

    def __init__(self, input_source, lex_state=LexicalState.${lexerData.lexicalStates[0].name}, line=1, column=1):
${globals.translateLexerInjections(true)}
        if not input_source:
            raise ValueError('input filename not specified')
        self.input_source = input_source
        text = _input_text(input_source)
        self.content = self.munge_content(text, ${PRESERVE_TABS}, ${PRESERVE_LINE_ENDINGS}, ${JAVA_UNICODE_ESCAPE}, ${TERMINATING_STRING})
        self.content_len = n = len(self.content)
        n += 1
        self.tab_size = DEFAULT_TAB_SIZE
[#if settings.lexerUsesParser]
        self.parser = None
[/#if]
        self._buffer_position = 0
        self._need_to_calculate_columns = BitSet(n)
        self._line_offsets = self.create_line_offsets_table(self.content)
        self._token_location_table = [None] * n
        self._token_offsets = BitSet(n)
        self._dummy_start_token = InvalidToken(self, 0, 0)
        self._ignored = IgnoredToken(self, 0, 0)
        self._skipped = SkippedToken(self, 0, 0)
        self._ignored.is_unparsed = True
        self._skipped.is_unparsed = True
        # The following two BitSets are used to store the current active
        # NFA states in the core tokenization loop
        self.next_states = BitSet(MAX_STATES)
        self.current_states = BitSet(MAX_STATES)

        self.active_token_types = set(TokenType)
  [#if settings.deactivatedTokens?size>0]
       [#list settings.deactivatedTokens as token]
        self.active_token_types.remove(TokenType.${token})
       [/#list]
  [/#if]
[#--
        # Holder for invalid characters, i.e. that cannot be matched as part of a token
        self.pending_invalid_chars = [] --]

        # Just used to "bookmark" the starting location for a token
        # for when we put in the location info at the end.
        self.starting_line = line
        self.starting_column = column

        # Token types that are "regular" tokens that participate in parsing,
        # i.e. declared as TOKEN
        [@EnumSet "regular_tokens" lexerData.regularTokens.tokenNames 8 /]
        # Token types that do not participate in parsing
        # i.e. declared as UNPARSED (or SPECIAL_TOKEN)
        [@EnumSet "unparsed_tokens" lexerData.unparsedTokens.tokenNames 8 /]
        [#-- Tokens that are skipped, i.e. SKIP --]
        [@EnumSet "skipped_tokens" lexerData.skippedTokens.tokenNames 8 /]
        # Tokens that correspond to a MORE, i.e. that are pending
        # additional input
        [@EnumSet "more_tokens" lexerData.moreTokens.tokenNames 8 /]
        self.invalid_token = None
        self.previous_token = None
        self.lexical_state = None
        self.switch_to(lex_state)

    #
    # An internal method for getting the next token.
    # Most of the work is done in the private method
    # _next_token, which invokes the NFA machinery
    #
    def _get_next_token(self):
        invalid_token = None
        token = self._next_token()
        while isinstance(token, InvalidToken):
            if invalid_token is None:
                invalid_token = token
            else:
                invalid_token.end_offset = token.end_offset
            token = self._next_token()
        if invalid_token:
            self.cache_token(invalid_token)
        self.cache_token(token)
        return invalid_token if invalid_token else token

    #
    # The public method for getting the next token.
    # If the tok parameter is None, it just tokenizes
    # starting at the internal buffer_position;
    # otherwise, it checks if we have already cached
    # the token after this one. If not, it finally
    # goes to the NFA machinery
    #

    def get_next_token(self, tok=None):
        if tok is None:
            return self._get_next_token()
        cached_token = tok.next_cached_token
        # If not currently active, discard it
        if cached_token and cached_token.type not in self.active_token_types:
            self.reset(tok)
            cached_token = None
        if cached_token:
            return cached_token
        return self.get_next_token_at_offset(tok.end_offset)

    def get_next_token_at_offset(self, offset):
        self.go_to(offset)
        return self.get_next_token(None)

    def read_char(self):
        bp = self._buffer_position
        cl = self.content_len
        tlt = self._token_location_table
        while tlt[bp] == self._ignored and bp < cl:
            bp += 1
        if bp >= cl:
            self._buffer_position = bp
            return ''
        ch = self.content[bp]
        self._buffer_position = bp + 1
        return ch

    # The main method to invoke the NFA machinery
    def _next_token(self):
        matched_token = None
        in_more = False
        token_begin_offset = self._buffer_position
        # first_char = ''
        # The core tokenization loop
        read_char = self.read_char
        # get_line_from_offset = self.get_line_from_offset
        # get_codepoint_column_from_offset = self.get_codepoint_column_from_offset
        while matched_token is None:
            matched_type = None
            matched_pos = code_units_read = 0
            reached_end = False
            if in_more:
                cur_char = read_char()
                if not cur_char:
                    reached_end = True
            else:
                token_begin_offset = self._buffer_position
                # first_char = cur_char = read_char()
                cur_char = read_char()
                if cur_char == '':
                    matched_type = TokenType.EOF
                    reached_end = True

[#if multipleLexicalStates]
            # Get the NFA function table current lexical state
            # There is some possibility that there was a lexical state change
            # since the last iteration of this loop!
[/#if]
            nfa_functions = get_function_table_map(self.lexical_state)
            # the core NFA loop
            if not reached_end:
                while True:
                    # Holder for the new type (if any) matched on this iteration
                    new_type = None
                    if code_units_read > 0:
                        # What was next_states on the last iteration
                        # is now the current_states!
                        temp = self.current_states
                        self.current_states = self.next_states
                        self.next_states = temp
                        retval = read_char()
                        if retval:
                            cur_char = retval
                        else:
                            reached_end = True
                            break
                    self.next_states.clear()
                    if code_units_read == 0:
                        returned_type = nfa_functions[0](cur_char, self.next_states, self.active_token_types)
                        if returned_type and (new_type is None or returned_type.value < new_type.value):
                            new_type = returned_type
                    else:
                        next_active = self.current_states.next_set_bit(0)
                        while next_active != -1:
                            returned_type = nfa_functions[next_active](cur_char, self.next_states, self.active_token_types)
                            if returned_type and (new_type is None or returned_type.value < new_type.value):
                                new_type = returned_type
                            next_active = self.current_states.next_set_bit(next_active + 1)
                    code_units_read += 1
                    if new_type:
                        matched_type = new_type
                        in_more = matched_type in self.more_tokens
                        matched_pos = code_units_read
                    if self.next_states.is_empty:
                        break
            if matched_type is None:
                self._buffer_position = token_begin_offset + 1
                return InvalidToken(self, token_begin_offset, self._buffer_position)
            self._buffer_position -= code_units_read - matched_pos
            if matched_type in self.skipped_tokens:
                tlt = self._token_location_table
                for i in range(token_begin_offset, self._buffer_position):
                    if tlt[i] is not self._ignored:
                        tlt[i] = self._skipped
            elif matched_type in self.regular_tokens or matched_type in self.unparsed_tokens:
                # import pdb; pdb.set_trace()
                matched_token = new_token(matched_type, self, token_begin_offset, self._buffer_position)
                matched_token.is_unparsed = matched_type not in self.regular_tokens
[#if lexerData.hasLexicalStateTransitions]
            self.do_lexical_state_switch(matched_type)
[/#if]
[#if lexerData.hasTokenActions]
            matched_token = self.token_lexical_actions(matched_token, matched_type)
[/#if]
[#list grammar.lexerTokenHooks as tokenHookMethodName]
  [#if tokenHookMethodName = "CommonTokenAction"]
        self.${tokenHookMethodName}(matched_token)
  [#else]
        matched_token = self.${tokenHookMethodName}(matched_token)
  [/#if]
[/#list]
        return matched_token

[#if multipleLexicalStates]
    def do_lexical_state_switch(self, token_type):
        new_state = token_type_to_lexical_state_map.get(token_type)
        if new_state is None:
            return False
        return self.switch_to(new_state)

[/#if]

    #
    # Switch to specified lexical state.
    #
    def switch_to(self, lex_state):
        if self.lexical_state != lex_state:
            self.lexical_state = lex_state
            return True
        return False

    def go_to(self, offset):
        tlt = self._token_location_table
        while tlt[offset] is self._ignored and offset < self.content_len:
            offset += 1
        self._buffer_position = offset

    # Reset the token source input
    # to just after the Token passed in.
    def reset(self, t, lex_state=None):
[#list grammar.resetTokenHooks as resetTokenHookMethodName]
        self.${globals.translateIdentifier(resetTokenHookMethodName)}(t)
[/#list]
        self.go_to(t.end_offset)
        self.uncache_tokens(t)
        if lex_state:
            self.switch_to(lex_state)
[#if multipleLexicalStates]
        else:
            self.do_lexical_state_switch(t.type)
[/#if]

 [#if lexerData.hasTokenActions]
    def token_lexical_actions(self, matched_token, matched_type):
    [#var idx = 0]
    [#list lexerData.regularExpressions as regexp]
        [#if regexp.codeSnippet?has_content]
        [#if idx > 0]el[/#if]if matched_type == TokenType.${regexp.label}:
${globals.translateCodeBlock(regexp.codeSnippet.javaCode, 12)}
          [#set idx = idx + 1]
        [/#if]
    [/#list]
        return matched_token
 [/#if]

    def munge_content(self, content, preserve_tabs, preserve_lines,
                      java_unicode_escape, terminating_string):
        if preserve_tabs and preserve_lines and not java_unicode_escape:
            if terminating_string :
                if content[-len(terminating_string):] != terminating_string :
                    return content
        tab_size=${settings.tabSize}
        buf = []
        index = 0
        # This is just to handle tabs to spaces. If you don't have that setting set, it
        # is really unused.
        col = 0
        # Don't know if this is really needed for Python ...
        code_points = list(content)
        cplen = len(code_points)
        while index < cplen:
            ch = code_points[index]
            index += 1
            if ch == '\n':
                buf.append(ch)
                col = 0
            elif java_unicode_escape and ch == '\\' and index < cplen and code_points[index] == 'u':
                num_preceding_slashes = 0
                i = index - 1
                while i >= 0:
                    if code_points[i] == '\\':
                        num_preceding_slashes += 1
                    else:
                        break
                    i -= 1
                if num_preceding_slashes % 2 == 0:
                    buf.append('\\')
                    col += 1
                    continue
                num_consecutive_us = 0
                i  = index
                while i < cplen:
                    if code_points[i] == 'u':
                        num_consecutive_us += 1
                    else:
                        break
                    i += 1
                four_hex_digits = ''.join(code_points[index + num_consecutive_us:index + num_consecutive_us + 4])
                buf.append(chr(int(four_hex_digits, 16)))
                index += num_consecutive_us + 4
                col += 1
            elif not preserve_lines and ch == '\r':
                buf.append('\n')
                col = 0
                if index < cplen and code_points[index] == '\n':
                    index += 1
            elif ch == '\t' and not preserve_tabs:
                spaces_to_add = tab_size - col % tab_size
                for i in range(spaces_to_add):
                    buf.append(' ')
                    col += 1
            else:
                buf.append(ch)
                col += 1
        if terminating_string :
            if content[-len(terminating_string):] != terminating_string :
                buf.append(terminating_string)
        return ''.join(buf)

    def create_line_offsets_table(self, content):
        if not content:
            return [0]
        length = len(content)
        line_count = 0
        length = len(content)
        for i in range(length):
            ch = content[i]
            if ch == '\t':
                self._need_to_calculate_columns.set(line_count)
            if ch == '\n':
                line_count += 1
        if content[-1] != '\n':
            line_count += 1
        result = [0]
        for i in range(length):
            ch = content[i]
            if ch == '\n':
                if (i + 1) == length:
                    break
                result.append(i + 1)
        return result

    def get_line_from_offset(self, pos):
        if pos >= self.content_len:
            result = len(self._line_offsets)
            if self.content[-1] != '\n':
                result -= 1
        else:
            sr = bisect.bisect_right(self._line_offsets, pos) - 1
            if sr >= 0:
                result = sr
            else:
                # import pdb; pdb.set_trace()
                result = sr + 1
        return self.starting_line + result

    def get_codepoint_column_from_offset(self, pos):
        if pos >= self.content_len:
            return 1
        if pos == 0:
            return self.starting_column
        # import pdb; pdb.set_trace()
        line = self.get_line_from_offset(pos) - self.starting_line
        line_start = self._line_offsets[line]
        start_col_adjustment = 1 if line > 0 else self.starting_column
        unadjusted_col = pos - line_start + start_col_adjustment
        if not self._need_to_calculate_columns[line]:
            return unadjusted_col
        result = start_col_adjustment
        i = line_start
        while i < pos:
            ch = self.content[i]
            if ch == '\t':
                result += self.tab_size - (result - 1) % self.tab_size
            else:
                result += 1
            i += 1
        return result

    def cache_token(self, tok):
[#if settings.tokenChaining]
        if tok.is_inserted:
            next = tok.next_cached_token
            if next:
                self.cache_token(next)
            return
[/#if]
        offset = tok.begin_offset
        tlt = self._token_location_table
        if tlt[offset] is not self._ignored:
            self._token_offsets.set(offset)
            tlt[offset] = tok

    def uncache_tokens(self, last_token):
        end_offset = last_token.end_offset
        if end_offset < self._token_offsets.bits:
            self._token_offsets.clear(end_offset, self._token_offsets.bits)
[#if settings.tokenChaining]
        last_token.unset_appended_token()
[/#if]

    def next_cached_token(self, offset):
        next_offset = self._token_offsets.next_set_bit(offset)
        return self._token_location_table[next_offset] if next_offset >= 0 else None

    def previous_cached_token(self, offset):
        prev_offset = self._token_offsets.previous_set_bit(offset - 1)
        return self._token_location_table[prev_offset] if prev_offset >= 0 else None

    def get_text(self, start_offset, end_offset):
        chars = []
        tlt = self._token_location_table
        content = self.content
        for offset in range(start_offset, end_offset):
            if tlt[offset] is not self._ignored:
                chars.append(content[offset])
        return ''.join(chars)

    def get_source_line(self, lineno):
        rln = lineno - self.starting_line
        if rln >= len(self._line_offsets):
            so = len(self.content)
        else:
            so = self._line_offsets[rln]
        rln += 1
        if rln >= len(self._line_offsets):
            eo = len(self.content)
        else:
            eo = self._line_offsets[rln]
        result = self.content[so:eo]
        if result[-1] == '\n':
            result = result[:-1]
        return result

    def set_region_ignore(self, start, end):
        tlt = self._token_location_table
        for offset in range(start, end):
            tlt[offset] = self._ignored
        self._token_offsets.clear(start, end)

    def at_line_start(self, tok):
        offset = tok.begin_offset
        while offset > 0:
            offset -= 1
            c = self.content[offset]
            if not c.isspace():
                return False
            if c == '\n':
                break
        return True

    def get_line_start_offset(self, lineno):
        rln = lineno - self.starting_line
        if rln <= 0:
            return 0
        if rln >= len(self._line_offsets):
            return self.content_len
        return self._line_offsets[rln]

    def get_line_end_offset(self, lineno):
        rln = lineno - self.starting_line
        if rln < 0:
            return 0
        if rln >= len(self._line_offsets):
            return self.content_len
        if rln == len(self._line_offsets) - 1:
            return self.content_len - 1
        return self._line_offsets[rln + 1] - 1

    def get_line(self, tok):
        lineno = tok.begin_line
        soff = self.get_line_start_offset(lineno)
        eoff = self.get_line_end_offset(lineno)
        return self.get_text(soff, eoff + 1)

    def set_line_skipped(self, tok):
        lineno = tok.begin_line
        soff = self.get_line_start_offset(lineno)
        eoff = self.get_line_start_offset(lineno + 1)
        self.set_region_ignore(soff, eoff)
        tok.begin_offset = soff
        tok.end_offset = eoff


${globals.translateLexerInjections(false)}

 [#if lexerData.hasLexicalStateTransitions]
# Generate the map for lexical state transitions from the various token types (if necessary)
    [#list grammar.lexerData.regularExpressions as regexp]
      [#if !regexp.newLexicalState?is_null]
token_type_to_lexical_state_map[TokenType.${regexp.label}] = LexicalState.${regexp.newLexicalState.name}
      [/#if]
    [/#list]
 [/#if]
