// Generated by ${generated_by}. Do not edit.
// ReSharper disable InconsistentNaming
[#var csPackage = globals::getPreprocessorSymbol('cs.package', settings.parserPackage) ]
namespace ${csPackage} {
    using System;
    using System.Collections.Generic;

    public enum TokenType {
 [#list lexerData.regularExpressions as regexp]
        ${regexp.label},
 [/#list]
 [#list settings.extraTokenNames as t]
        ${t},
 [/#list]
        INVALID
    }

    public enum LexicalState {
[#list lexerData.lexicalStates as lexicalState]
     ${lexicalState.name}[#if lexicalState_has_next],[/#if]
[/#list]
    }

    public interface Node {
        void Open() {}
        void Close() {}
        Lexer TokenSource { get; set; }
        Node Parent { get; set; }
        int Size { get; }
        Node Get(int i);
        void Set(int i, Node n);
        void Add(int i, Node n);
        void Add(Node n);
        void Remove(int i);
        void Clear();

        // default implementations

        string InputSource { get {
            var ts = TokenSource;

            return (ts == null) ? "input" : ts.InputSource;
        } }

        int BeginOffset { get; set; }
        int EndOffset { get; set; }

        int BeginLine => TokenSource?.GetLineFromOffset(BeginOffset) ?? 0;

        int EndLine => TokenSource?.GetLineFromOffset(EndOffset - 1) ?? 0;

        int BeginColumn => TokenSource?.GetCodePointColumnFromOffset(BeginOffset) ?? 0;

        int EndColumn => TokenSource?.GetCodePointColumnFromOffset(EndOffset - 1) ?? 0;

        string Location => $"{InputSource}:{BeginLine}:{BeginColumn}";

        bool IsUnparsed => false;

        bool HasChildNodes => Size > 0;

        int IndexOf(Node child) {
            for (var i = 0; i < Size; i++) {
                if (child == Get(i)) {
                    return i;
                }
            }
            return -1;
        }

        Node FirstChild => (Size > 0) ? Get(0) : null;

        Node LastChild {
            get {
                var n = Size;
                return (n > 0) ? Get(n - 1) : null;
            }
        }

        Node Root {
            get {
                var n = this;
                while(n.Parent != null) {
                    n = n.Parent;
                }
                return n;
            }
        }

        ListAdapter<Node> Children {
            get {
                var result = new ListAdapter<Node>();

                for (var i = 0; i < Size; i++) {
                    result.Add(Get(i));
                }
                return result;
            }
        }

        bool Remove(Node n) {
            var i = IndexOf(n);
            if (i < 0) {
                return false;
            }
            Remove(i);
            return true;
        }


        bool ReplaceChild(Node current, Node replacement) {
            var i = IndexOf(current);
            if (i < 0) {
                return false;
            }
            Set(i, replacement);
            return true;
        }

        bool PrependChild(Node where, Node inserted) {
            var i = IndexOf(where);
            if (i < 0) {
                return false;
            }
            Add(i, inserted);
            return true;
        }

        bool AppendChild(Node where, Node inserted) {
            var i = IndexOf(where);
            if (i < 0) {
                return false;
            }
            Add(i + 1, inserted);
            return true;
        }

        T FirstChildOfType<T>(Type t) where T : Node {
            var result = default(T);

            for (var i = 0; i < Size; i++) {
                var child = Get(i);
                if (!t.IsInstanceOfType(child)) continue;
                result = (T)child;
            }
            return result;
        }

        T FirstChildOfType<T>(Type t, Predicate<T> pred) where T : Node {
            var result = default(T);

            for (var i = 0; i < Size; i++) {
                var child = Get(i);
                if (!t.IsInstanceOfType(child)) continue;
                var c = (T)child;
                if (!pred(c)) continue;
                result = c;
                break;
            }
            return result;
        }

        void CopyLocationInfo(Node start, Node end = null) {
            TokenSource = start.TokenSource;
            BeginOffset = start.BeginOffset;
            EndOffset = start.EndOffset;
            if (end == null) return;
            TokenSource ??= end.TokenSource;
            EndOffset = end.EndOffset;
        }

        void Replace(Node toBeReplaced) {
            CopyLocationInfo(toBeReplaced);
            var parent = toBeReplaced.Parent;
            if (parent == null) return;
            var index = parent.IndexOf(toBeReplaced);
            parent.Set(index, this);
        }

#if settings.tokensAreNodes
        Token FirstDescendantOfType(TokenType tt) {
            for (var i = 0; i < Size; i++) {
                var child = Get(i);
                Token tok;

                if (child is Token token) {
                    tok = token;
                    if (tt == tok.Type) {
                        return tok;
                    }
                }
                else {
                    tok = child.FirstDescendantOfType(tt);
                    if (tok != null) {
                        return tok;
                    }
                }
            }
            return null;
        }

        Token FirstChildOfType(TokenType tt) {
            for (var i = 0; i < Size; i++) {
                var child = Get(i);
                if (!(child is Token tok)) continue;
                if (tt == tok.Type) {
                    return tok;
                }
            }
            return null;
        }

        ListAdapter<T> ChildrenOfType<T>(Type t) where T : Node {
            var result = new ListAdapter<T>();

            for (var i = 0; i < Size; i++) {
                var child = Get(i);
                if (t.IsInstanceOfType(child)) {
                    result.Add((T) child);
                }
            }
            return result;
        }

        ListAdapter<T> DescendantsOfType<T>(Type t) where T : Node {
            var result = new ListAdapter<T>();

            for (var i = 0; i < Size; i++) {
                var child = Get(i);
                if (t.IsInstanceOfType(child)) {
                    result.Add((T) child);
                }
                result.AddRange(child.DescendantsOfType<T>(t));
            }
            return result;
        }

        ListAdapter<T> Descendants<T>(Type t, Predicate<T> predicate) where T : Token {
            var result = new ListAdapter<T>();

            for (var i = 0; i < Size; i++) {
                var child = Get(i);
                if (t.IsInstanceOfType(child)) {
                    var c = (T) child;
                    if ((predicate == null) || predicate(c)) {
                        result.Add(c);
                    }
                }
                result.AddRange(child.Descendants(t, predicate));
            }
            return result;
        }

        internal ListAdapter<Token> GetRealTokens() {
            return Descendants<Token>(typeof(Token), t => !t.IsUnparsed);
        }

        //
        // Return the very first token that is part of this node.
        // It may be an unparsed (i.e. special) token.
        //
        public Token FirstToken {
            get {
                var first = FirstChild;
                switch (first)
                {
                    case null:
                        return null;
                    case Token token:
                    {
                        var tok = token;
                        while (tok.PreviousCachedToken is {IsUnparsed: true}) {
                            tok = tok.PreviousCachedToken;
                        }
                        return tok;
                    }
                    default:
                        return first.FirstToken;
                }
            }
        }

        public Token LastToken {
            get {
                var last = LastChild;
                return last switch
                {
                    null => null,
                    Token token => token,
                    _ => last.LastToken
                };
            }
        }

/#if
    }

#if settings.faultTolerant
    interface ParsingProblem : Node {
        ParseException Cause { get; }
        string ErrorMessage { get; }
    }

/#if
    public class BaseNode : Node {
        public Node Parent { get; set; }
        public int BeginOffset { get; set; }
        public int EndOffset { get; set; }

        // TODO use default implementations in interface
        public int BeginLine => TokenSource?.GetLineFromOffset(BeginOffset) ?? 0;

        public int EndLine => TokenSource?.GetLineFromOffset(EndOffset - 1) ?? 0;

        public int BeginColumn => TokenSource?.GetCodePointColumnFromOffset(BeginOffset) ?? 0;

        public int EndColumn => TokenSource?.GetCodePointColumnFromOffset(EndOffset - 1) ?? 0;

        public T FirstChildOfType<T>(Type t) where T : Node {
            var result = default(T);

            for (var i = 0; i < Size; i++) {
                var child = Get(i);
                if (!t.IsInstanceOfType(child)) continue;
                result = (T) child;
                break;
            }
            return result;
        }

        public ListAdapter<T> ChildrenOfType<T>(Type t) where T : Node {
            var result = new ListAdapter<T>();

            for (var i = 0; i < Size; i++) {
                var child = Get(i);
                if (t.IsInstanceOfType(child)) {
                    result.Add((T) child);
                }
            }
            return result;
        }

        internal Lexer tokenSource;
        protected ListAdapter<Node> children { get; private set; } = new ListAdapter<Node>();

        public Lexer TokenSource {
            get {
                if (tokenSource != null) return tokenSource;
                foreach (var child in children) {
                    tokenSource = child.TokenSource;
                    if (tokenSource != null) {
                        break;
                    }
                }
                return tokenSource;
            }
            set => tokenSource = value;
        }

        public ListAdapter<Node>Children => new ListAdapter<Node>(children);

        public Node Get(int i) {
            return children[i];
        }

        public void Set(int i, Node n) {
            children[i] = n;
            n.Parent = this;
        }

        public void Add(Node n) {
            children.Add(n);
            n.Parent = this;
        }

        public void Add(int i, Node n) {
            children.Insert(i, n);
            n.Parent = this;
        }

        public void Clear() => children.Clear();

[#if settings.nodeUsesParser]
        internal Parser parser;
[/#if]

[#if settings.nodeUsesParser]
        public BaseNode(Parser parser) {
            this.parser = parser;
            this(parser.InputSource);
        }

[/#if]
        public BaseNode(Lexer tokenSource) {
            this.tokenSource = tokenSource;
        }

        public void Add(BaseNode node) {
            Add(node, -1);
        }

        public void Add(BaseNode node, int index) {
            if (index < 0) {
                children.Add(node);
            }
            else {
                children.Insert(index, node);
            }
            node.Parent = this;
        }

        public void Remove(int index) {
            children.RemoveAt(index);
        }

        public int Size => children.Count;

        protected IDictionary<string, Node> NamedChildMap;
        protected IDictionary<string, IList<Node>> NamedChildListMap;

        public Node GetNamedChild(string name) {
            if (NamedChildMap == null) {
                return null;
            }
            return !NamedChildMap.ContainsKey(name) ? null : NamedChildMap[name];
        }

        public void SetNamedChild(string name, Node node) {
            NamedChildMap ??= new Dictionary<string, Node>();
            if (NamedChildMap.ContainsKey(name)) {
                const string msg = @"Duplicate named child not allowed: {name}";
                throw new ApplicationException(msg);
            }
            NamedChildMap[name] = node;
        }

        public IList<Node> GetNamedChildList(string name) {
            if (NamedChildListMap == null) {
                return null;
            }
            return !NamedChildListMap.ContainsKey(name) ? null : NamedChildListMap[name];
        }

        public void AddToNamedChildList(string name, Node node) {
            NamedChildListMap ??= new Dictionary<string, IList<Node>>();

            IList<Node> nodeList;

            if (NamedChildListMap.ContainsKey(name)) {
                nodeList = NamedChildListMap[name];
            }
            else {
                nodeList = new List<Node>();
                NamedChildListMap[name] = nodeList;
            }
            nodeList.Add(node);
        }

[#if settings.faultTolerant]
        private bool dirty;

        public bool IsDirty() {
            return dirty;
        }

        public void SetDirty(bool value) {
            dirty = value;
        }

[/#if]

    }

    public class InvalidNode : BaseNode {
        public InvalidNode(Lexer tokenSource) : base(tokenSource) {}
    }

    public class Token[#if settings.treeBuildingEnabled] : Node[/#if] {

        public Lexer TokenSource { get; set; }
        public int BeginOffset { get; set; }
        public int EndOffset { get; set; }
        public Node Parent { get; set; }
        public int Size => 0;
        public Node Get(int i) => null;
        public ListAdapter<Node> Children => new ListAdapter<Node>();
        public void Set(int i, Node n) { throw new NotSupportedException(); }
        public void Add(Node n) { throw new NotSupportedException(); }
        public void Add(int i, Node n) { throw new NotSupportedException(); }
        public void Remove(int i) { throw new NotSupportedException(); }
        public void Clear() {}

        public void Truncate(int amount) {
            var newEndOffset = Math.Max(BeginOffset, EndOffset - amount);
            EndOffset = newEndOffset;
        }

        // TODO use default implementations in interface
        public int BeginLine => TokenSource?.GetLineFromOffset(BeginOffset) ?? 0;

        public int EndLine => TokenSource?.GetLineFromOffset(EndOffset - 1) ?? 0;

        public int BeginColumn => TokenSource?.GetCodePointColumnFromOffset(BeginOffset) ?? 0;

        public int EndColumn => TokenSource?.GetCodePointColumnFromOffset(EndOffset - 1) ?? 0;

        public TokenType Type { get; internal set; }

[#if !settings.treeBuildingEnabled]
        internal bool IsUnparsed;
[#else]
        public bool IsUnparsed { get; internal set; }
[/#if]

[#if settings.tokenChaining || settings.faultTolerant]
        private string _image;

        public string Image {
            get {
                return _image != null ? _image: Source;
            }
            set { _image = value; }
        }

        public string CachedImage {
            get {
                return _image != null ? _image: Source;
            }
            set { _image = value; }
        }
[#else]
        public string Image => Source;
[/#if]
        public override string ToString() {
            return Image;
        }

        public virtual bool IsSkipped() {
[#if settings.faultTolerant]
           return skipped;
[#else]
           return false;
[/#if]
        }

        public virtual bool IsVirtual() {
[#if settings.faultTolerant]
           return _virtual || Type == TokenType.EOF;
[#else]
           return Type == TokenType.EOF;
[/#if]
        }

[#if settings.faultTolerant]
        private bool _virtual, skipped, dirty;

        internal void SetVirtual(bool value) {
            _virtual = value;
            if (_virtual) {
                dirty = true;
            }
        }

        internal void SetSkipped(bool value) {
            skipped = value;
            if (skipped) {
                dirty = true;
            }
        }

        public bool IsDirty() {
            return dirty;
        }

        public void SetDirty(bool value) {
            dirty = value;
        }

[/#if]

        /**
        * @param type the #TokenType of the token being constructed
        * @param image the String content of the token
        * @param tokenSource the object that vended this token.
        */
        public Token(TokenType kind, Lexer tokenSource, int beginOffset, int endOffset) {
            Type = kind;
            TokenSource = tokenSource;
            BeginOffset = beginOffset;
            EndOffset = endOffset;
[#if !settings.treeBuildingEnabled]
            TokenSource = tokenSource;
[/#if]
        }

[#if settings.tokenChaining]

        internal Token prependedToken, appendedToken;

        internal bool isInserted;

        internal void PreInsert(Token prependedToken) {
            if (prependedToken == this.prependedToken) {
                return;
            }
            prependedToken.appendedToken = this;
            Token existingPreviousToken = this.PreviousCachedToken;
            if (existingPreviousToken != null) {
                existingPreviousToken.appendedToken = prependedToken;
                prependedToken.prependedToken = existingPreviousToken;
            }
            prependedToken.isInserted = true;
            prependedToken.BeginOffset = prependedToken.EndOffset = this.BeginOffset;
            this.prependedToken = prependedToken;
        }

        internal void UnsetAppendedToken() {
            appendedToken = null;
        }

        internal static Token NewToken(TokenType type, String image, Lexer tokenSource) {
            Token result = NewToken(type, tokenSource, 0, 0);
            result.Image = image;
            return result;
        }
    [/#if]

        internal static Token NewToken(TokenType type, Lexer tokenSource, int beginOffset, int endOffset) {
[#if settings.treeBuildingEnabled]
            return type switch {
  [#list lexerData.orderedNamedTokens as re]
    [#if re.generatedClassName != "Token" && !re.private]
                TokenType.${re.label} => new ${grammar.nodePrefix}${re.generatedClassName}(TokenType.${re.label}, tokenSource, beginOffset, endOffset),
    [/#if]
  [/#list]
  [#list settings.extraTokenNames as tokenName]
                TokenType.${tokenName} => new ${grammar.nodePrefix}${settings.extraTokens[tokenName]}(TokenType.${tokenName}, tokenSource, beginOffset, endOffset),
  [/#list]
                TokenType.INVALID => new InvalidToken(tokenSource, beginOffset, endOffset),
                _ => new Token(type, tokenSource, beginOffset, endOffset)
            };
[#else]
            return new Token(type, tokenSource, beginOffset, endOffset);
[/#if]
        }

        internal Token NextToken { get; set; }
        internal string Location {
            get {
                var n = (Node) this;

                return $"{TokenSource.InputSource}:{n.BeginLine}:{n.BeginColumn}";
            }
        }

[#if settings.treeBuildingEnabled && settings.tokenChaining]
        // Copy the location info from another node or start/end nodes
        internal void CopyLocationInfo(Node start, Node end = null) {
            ((Node) this).CopyLocationInfo(start, end);
            if (start is Token otherTok) {
                appendedToken = otherTok.appendedToken;
                prependedToken = otherTok.prependedToken;
            }
            if (end != null) {
                if (end is Token endToken) {
                    appendedToken = endToken.appendedToken;
                }
            }
        }
[#else]
        internal void CopyLocationInfo(Token start, Token end = null) {
            TokenSource = start.TokenSource;
            BeginOffset = start.BeginOffset;
            EndOffset = start.EndOffset;
[#if settings.tokenChaining]
            appendedToken = start.appendedToken;
            prependedToken = start.prependedToken;
[/#if]
            if (end != null) {
[#if settings.tokenChaining]
                appendedToken = end.appendedToken;
[/#if]
            }
        }

[/#if]
        internal Token Next => NextParsedToken;

        internal Token Previous {
            get {
                var result = PreviousCachedToken;
                while (result is {IsUnparsed: true}) {
                    result = result.PreviousCachedToken;
                }
                return result;
            }
        }

        internal Token NextParsedToken {
            get {
                var result = NextCachedToken;
                while (result is {IsUnparsed: true}) {
                    result = result.NextCachedToken;
                }
                return result;
            }
        }

        internal Token NextCachedToken {
            get {
[#if settings.tokenChaining]
                if (appendedToken != null) {
                    return appendedToken;
                }
[/#if]
                return TokenSource?.NextCachedToken(EndOffset);
            }
        }

        internal Token PreviousCachedToken {
            get {
[#if settings.tokenChaining]
                if (prependedToken !=null) {
                    return prependedToken;
                }
[/#if]
                return TokenSource?.PreviousCachedToken(BeginOffset);
            }
        }

        internal Token PreviousToken => PreviousCachedToken;

        internal Token ReplaceType(TokenType type) {
            var result = NewToken(Type, TokenSource, BeginOffset, EndOffset);
[#if settings.tokenChaining]
            result.prependedToken = prependedToken;
            result.appendedToken = appendedToken;
            result.isInserted = isInserted;
            if (result.appendedToken != null) {
                result.appendedToken.prependedToken = result;
            }
            if (result.prependedToken != null) {
                result.prependedToken.appendedToken = result;
            }
            if (!result.isInserted) {
                TokenSource.CacheToken(result);
            }
[#else]
            TokenSource.CacheToken(result);
[/#if]
            return result;
        }

        public string Source => Type == TokenType.EOF ? "" : TokenSource?.GetText(BeginOffset, EndOffset);

        private IEnumerable<Token> precedingTokens() {
            var current = this;

            while (current.PreviousCachedToken is { } t) {
                current = t;
                yield return current;
            }
        }

        internal Iterator<Token> PrecedingTokens() {
            return new GenWrapper<Token>(precedingTokens());
        }

[#if unwanted!false]
        private IEnumerable<Token> followingTokens() {
            Token current = this;
            Token t;

            while ((t = current.NextCachedToken) != null) {
                current = t;
                yield return current;
            }
        }

        internal ListIterator<Token>? FollowingTokens() {
            return null;
        }

[/#if]

${globals::translateTokenInjections(true)}

${globals::translateTokenInjections(false)}

    }

    // Token subclasses

[#var tokenSubClassInfo = globals::tokenSubClassInfo()]
[#list tokenSubClassInfo.sortedNames as name]
    public class ${name} : ${tokenSubClassInfo.tokenClassMap[name]} {
        public ${name}(TokenType kind, Lexer tokenSource, int beginOffset, int endOffset) : base(kind, tokenSource, beginOffset, endOffset) {}
    }

[/#list]

#if settings.extraTokens?size > 0
  #list settings.extraTokenNames as name
    #var cn = settings.extraTokens[name]
    public class ${cn} : Token {
        public ${cn}(TokenType kind, Lexer tokenSource, int beginOffset, int endOffset) : base(kind, tokenSource, beginOffset, endOffset) {}

${globals::translateTokenSubclassInjections(cn, true)}
${globals::translateTokenSubclassInjections(cn, false)}
    }

  /#list
/#if


    public class InvalidToken : Token[#if settings.faultTolerant], ParsingProblem[/#if] {
        public InvalidToken(Lexer tokenSource, int beginOffset, int endOffset) : base(TokenType.INVALID, tokenSource, beginOffset, endOffset) {
#if settings.faultTolerant
            SetDirty(true);
/#if
        }
#if settings.faultTolerant

        public ParseException Cause { get; internal set; }

        private string errorMessage;

        public string ErrorMessage {
            get {
                if (errorMessage != null) return errorMessage;
                return "lexically invalid input"; // REVISIT
            }
        }
/#if
    }
}
