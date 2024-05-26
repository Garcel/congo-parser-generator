/* Generated by: ${generated_by}. ${filename} ${settings.copyrightBlurb} */
package ${settings.parserPackage};

import java.io.PrintStream;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.lang.reflect.*;
import java.util.function.Predicate;

public interface Node extends List<Node> {

    // Marker interface for objects
    // that represent a node's type, i.e. TokenType
    public interface NodeType {
        boolean isUndefined();
        boolean isInvalid();
        boolean isEOF();
        default String getLiteralString() {
            return null; // unimplemented currently.
        }
    }

    //Marker interface for tokens
    public interface TerminalNode extends Node {
        [#-- I added this so that code compiles. Not sure
             what I am doing with this.. --]
        TerminalNode getNext();
        List<? extends TerminalNode> precedingUnparsedTokens();

        default void truncate(int amount) {
            int newEndOffset = Math.max(getBeginOffset(), getEndOffset()-amount);
            setEndOffset(newEndOffset);
        }

        default boolean add(Node n) {
            throw new UnsupportedOperationException("This is a terminal node. It has no child nodes.");
        }

        default void add(int i, Node n) {
            throw new UnsupportedOperationException("This is a terminal node. It has no child nodes.");
        }

        default Node remove(int i) {
            throw new UnsupportedOperationException("This is a terminal node. It has no child nodes.");
        }

        default boolean remove(Object obj) {
            throw new UnsupportedOperationException("This is a terminal node. It has no child nodes.");
        }

        default Node set(int i, Node n) {
            throw new UnsupportedOperationException("This is a terminal node. It has no child nodes.");
        }

        default int indexOf(Node n) {
            return -1;
        }

        default int size() {
            return 0;
        }

        default Node get(int i) {
            throw new UnsupportedOperationException("This is a terminal node. It has no child nodes.");
        }

        default List<Node> children() {
            return java.util.Collections.emptyList();
        }

        default void clearChildren() {}
    }

    default NodeType getType() { return null; }

    /** Life-cycle hook method called after the node has been made the current
     *  node
     */
    default void open() {}

    /**
     * Life-cycle hook method called after all the child nodes have been
     * added.
     */
    default void close() {}


    /**
     * @return the input source (usually a filename) from which this Node came from
     */
    default String getInputSource() {
        TokenSource tokenSource = getTokenSource();
        return tokenSource == null ? "input" : tokenSource.getInputSource();
    }

   /**
     * Returns whether this node has any children.
     *
     * @return Returns <code>true</code> if this node has any children,
     *         <code>false</code> otherwise.
     */
    default boolean hasChildNodes() {
       return size() > 0;
    }

    /**
     * @param n The Node to set as the parent. Mostly used internally.
     * The various addChild or appendChild sorts of methods should use this
     * to set the node's parent.
     */
    void setParent(Node n);

    /**
     * @return this node's parent Node
     */
    Node getParent();

     // The following 9 methods will typically just
     // delegate straightforwardly to a List object that
     // holds the child nodes

    /**
     * appends a child Node
     * @deprecated Use #add(Node)
     */
     @Deprecated
     default void addChild(Node n) {
        add(n);
     }

     /**
      * inserts a child Node at a specific index, displacing the
      * nodes after the index by 1.
      * @param i the (zero-based) index at which to insert the node
      * @param n the Node to insert
      * @deprecated Use #add(int,Node)
      */
     @Deprecated
     default void addChild(int i, Node n) {
        add(i, n);
     }

     /**
      * @return the Node at the specific offset
      * @param i the index of the Node to return
      * @deprecated Use #get(int)
      */
     @Deprecated
     default Node getChild(int i) {
        return get(i);
     }

     /**
      * Replace the node at index i
      * @param i the index
      * @param n the node
      * @deprecated Use #set(int,Node)
      */
     @Deprecated
     default void setChild(int i, Node n) {set(i,n);}

     /**
      * Remove the node at index i. Any Nodes after i
      * are shifted to the left.
      * @return the removed Node
      * @param i the index at which to remove
      * @deprecated Use #remove(int)
      */
     @Deprecated
     default Node removeChild(int i) {return remove(i);}

     /**
      * Removes the Node from this node's children
      * @param n the Node to remove
      * @return whether the Node was present
      * @deprecated Use #remove(Node)
      */
     @Deprecated
     default boolean removeChild(Node n) {
         return remove(n);
     }

     /**
      * Replaces a child node with another one. It does
      * nothing if the first parameter is not actually a child node.
      * @param current the Node to be replaced
      * @param replacement the Node to substitute
      * @return whether any replacement took place
      * @deprecated Use #replace(Node,Node)
      */
     @Deprecated
     default boolean replaceChild(Node current, Node replacement) {
         return replace(current, replacement);
     }


     /**
      * Replaces a child node with another one. It does
      * nothing if the first parameter is not actually a child node.
      * @param current the Node to be replaced
      * @param replacement the Node to substitute
      * @return whether any replacement took place
      */
     default boolean replace(Node current, Node replacement) {
         int index = indexOf(current);
         if (index == -1) return false;
         setChild(index, replacement);
         current.setParent(null);
         return true;
     }


     /**
      * Insert a Node right before a given Node. It does nothing
      * if the where Node is not actually a child node.
      * @param where the Node that is the location where to prepend
      * @param inserted the Node to prepend
      * @return whether a Node was prepended
      */
     default boolean prependChild(Node where, Node inserted) {
         int index = indexOf(where);
         if (index == -1) return false;
         addChild(index, inserted);
         return true;
     }

     /**
      * Insert a node right after a given Node. It does nothing
      * if the where node is not actually a child node.
      * @param where the Node after which to append
      * @param inserted the Node to be inserted
      * @return whether a Node really was appended
      */
     default boolean appendChild(Node where, Node inserted) {
         int index = indexOf(where);
         if (index == -1) return false;
         addChild(index + 1, inserted);
         return true;
     }

     /**
      * @return the index of the child Node. Or -1 if it is not
      * a child Node.
      * @param child the Node to get the index of
      */
     default int indexOf(Node child) {
         for (int i = 0; i < size(); i++) {
             if (child == get(i)) {
                 return i;
             }
         }
         return -1;
     }

     default Node previousSibling() {
         Node parent = getParent();
         if (parent == null) return null;
         int idx = parent.indexOf(this);
         if (idx <= 0) return null;
         return parent.get(idx - 1);
     }

     default Node nextSibling() {
         Node parent = getParent();
         if (parent == null) return null;
         int idx = parent.indexOf(this);
         if (idx >= parent.size() - 1) return null;
         return parent.get(idx + 1);
     }

     /**
      * Remove all the child nodes
      * @deprecated Use clear()
      */
     @Deprecated
     default void clearChildren() {clear();}

     /**
      * @return the number of child nodes
      * @deprecated Use #size()
      */
     @Deprecated
     default int getChildCount() {return size();}

     /**
      * @return a List containing this node's child nodes
      * The default implementation returns a copy, so modifying the
      * list that is returned has no effect on this object. Most
      * implementations of this should similarly return a copy or
      * possibly immutable wrapper around the list.
      */
      default List<Node> children(boolean includeUnparsedTokens) {
         List<Node> result = new ArrayList<>();
         for (int i = 0; i < size(); i++) {
             Node child = get(i);
             if (includeUnparsedTokens && child instanceof TerminalNode) {
                 TerminalNode tok = (TerminalNode) child;
                 if (!tok.isUnparsed()) {
                     result.addAll(tok.precedingUnparsedTokens());
                 }
             }
             result.add(child);
         }
         return result;
      }

      default List<Node> children() {
          List<Node> result = new ArrayList<>();
          for (int i = 0; i < size(); i++) {
              result.add(get(i));
          }
          return result;
      }

      default List<Node> children(Predicate<? super Node> predicate) {
          List<Node> result = new ArrayList<>();
          for (int i = 0; i < size(); i++) {
               Node child = get(i);
               if (predicate == null || predicate.test(child)) {
                  result.add(child);
               }
          }
          return result;
      }

      default public List<? extends TerminalNode> getAllTokens(boolean includeCommentTokens) {
        List<TerminalNode> result = new ArrayList<>();
        for (Node child : this) {
            if (child instanceof TerminalNode) {
                TerminalNode tn = (TerminalNode) child;
                if (tn.isUnparsed()) {
                    continue;
                }
                if (includeCommentTokens) {
                    result.addAll(tn.precedingUnparsedTokens());
                }
                result.add(tn);
            }
            else if (child.size() > 0) {
               result.addAll(child.getAllTokens(includeCommentTokens));
            }
        }
        return result;
    }

     /**
      * @return the #TokenSource from which this Node object
      * originated. There is no guarantee that this doesn't return null.
      * Most likely that would simply be because you constructed the
      * Node yourself, i.e. it didn't really come about via the parsing/tokenizing
      * machinery.
      */
     TokenSource getTokenSource();

     void setTokenSource(TokenSource tokenSource);

     /**
      * @return the original source content this Node came from
      * a reference to the #TokenSource that stores the source code and
      * the start/end location info stored in the Node object itself.
      * This method could throw a NullPointerException if #getTokenSource
      * returns null. Also, the return value could be spurious if
      * the content of the source file was changed meanwhile. But
      * this is just the default implementation of an API and it does not
      * address this problem!
      */
    default String getSource() {
        TokenSource tokenSource = getTokenSource();
        return tokenSource == null ? null : tokenSource.getText(getBeginOffset(), getEndOffset());
    }

    default String getImage() {
        return getSource();
    }

    default int getLength() {
        return getEndOffset() - getBeginOffset();
    }

    /**
     * @return the (1-based) line location where this Node starts
     */
    default int getBeginLine() {
        TokenSource tokenSource = getTokenSource();
        return tokenSource == null ? 0 : tokenSource.getLineFromOffset(getBeginOffset());
    };

    /**
     * @return the (1-based) line location where this Node ends
     */
    default int getEndLine() {
        TokenSource tokenSource = getTokenSource();
        return tokenSource == null ? 0 : tokenSource.getLineFromOffset(getEndOffset() - 1);
    };

    /**
     * @return the (1-based) column where this Node starts
     */
    default int getBeginColumn() {
        TokenSource tokenSource = getTokenSource();
        return tokenSource == null ? 0 : tokenSource.getCodePointColumnFromOffset(getBeginOffset());
    };

    /**
     * @return the (1-based) column offset where this Node ends
     */
    default int getEndColumn() {
        TokenSource tokenSource = getTokenSource();
        return tokenSource == null ? 0 : tokenSource.getCodePointColumnFromOffset(getEndOffset() - 1);
    }

    /**
     * @return the offset in the input source where the token begins,
     * expressed in code units.
     */
    int getBeginOffset();

    /**
     * @return the offset in the input source where the token ends,
     * expressed in code units. This is actually the offset where the
     * very next token would begin.
     */
     int getEndOffset();

     /**
      * Set the offset where the token begins, expressed in code units.
      */
      void setBeginOffset(int beginOffset);

     /**
      * Set the offset where the token ends, actually the location where
      * the very next token should begin.
      */
      void setEndOffset(int endOffet);

    /**
     * @return a String that gives the starting location of this Node. This is a default
     * implementation that could be overridden
     */
    default String getLocation() {
         return getInputSource() + ":" + getBeginLine() + ":" + getBeginColumn();
    }

     /**
      * @return whether this Node was created by regular operations of the
      * parsing machinery.
      */
     default boolean isUnparsed() {
        return false;
     }

     /**
      * Mark whether this Node is unparsed, i.e. <i>not</i> the result of
      * normal parsing
      * @param b whether to set the Node as unparsed or parsed.
      */
    void setUnparsed(boolean b);

    default <T> T firstChildOfType(Class<T>clazz) {
        return firstChildOfType(clazz, null);
    }

    default <T> T firstChildOfType(Class<T> clazz, Predicate<? super T> pred) {
        for (int i = 0; i < size(); i++) {
            Node child = get(i);
            if (clazz.isInstance(child)) {
                T t = clazz.cast(child);
                if (pred == null || pred.test(t)) return t;
            }
        }
        return null;
    }

    default Node firstDescendantOfType(NodeType type, Predicate<? super Node> pred) {
         for (int i = 0; i < size(); i++) {
             Node child = get(i);
             if (child.getType() == type) {
                if (pred == null || pred.test(child)) return child;
             } else {
                 Node tok = child.firstDescendantOfType(type, pred);
                 if (tok != null) return tok;
             }
         }
         return null;
    }

    default Node firstDescendantOfType(NodeType type) {
        return firstDescendantOfType(type, null);
    }

    default Node firstChildOfType(NodeType type) {
        for (int i = 0; i < size(); i++) {
            Node child = get(i);
            if (child.getType() == type) return child;
        }
        return null;
    }

    default <T extends Node>T firstDescendantOfType(Class<T> clazz, Predicate<? super T> pred) {
         for (int i = 0; i < size(); i++) {
             Node child = get(i);
             if (clazz.isInstance(child)) {
                T t = clazz.cast(child);
                if (pred == null || pred.test(t)) return t;
             }
             else {
                 T descendant = child.firstDescendantOfType(clazz, pred);
                 if (descendant != null) return descendant;
             }
         }
         return null;
    }

    default <T extends Node> T firstDescendantOfType(Class<T> clazz) {
        return firstDescendantOfType(clazz, null);
    }

    default <T> List<T> childrenOfType(Class<T> clazz, Predicate<? super T> pred) {
        List<T>result = new java.util.ArrayList<>();
        for (int i = 0; i < size(); i++) {
            Node child = get(i);
            if (clazz.isInstance(child)) {
                T t = clazz.cast(child);
                if (pred == null || pred.test(t)) result.add(t);
            }
        }
        return result;
   }

   default List<Node> childrenOfType(NodeType type, Predicate<? super Node> pred) {
      List<Node> result = new java.util.ArrayList<>();
      for (int i = 0; i < size(); i++) {
          Node child = get(i);
          if (child.getType() == type) {
             if (pred == null || pred.test(child)) result.add(child);
          }
      }
      return result;
   }

   default List<Node> childrenOfType(NodeType type) {
      return childrenOfType(type, null);
   }

   default <T> List<T> childrenOfType(Class<T> clazz) {
       return childrenOfType(clazz, null);
   }

   default <T extends Node> List<T> descendantsOfType(Class<T> clazz, Predicate<? super T> pred) {
        return descendants(clazz, pred);
   }

   default <T extends Node> List<T> descendantsOfType(Class<T> clazz) {
       return descendants(clazz, null);
   }

   default <T extends Node> T firstAncestorOfType(Class<T> clazz) {
        Node parent = this;
        while (parent != null) {
           parent = parent.getParent();
           if (clazz.isInstance(parent)) {
               return clazz.cast(parent);
           }
        }
        return null;
    }

    /**
     * @deprecated Just use #getType instead
     */
    @Deprecated
    default NodeType getTokenType() {
        return getType();
    }

    /**
     * Copy the location info from another Node
     * @param from the Node to copy the info from
     */
    default void copyLocationInfo(Node from) {
        setTokenSource(from.getTokenSource());
        setBeginOffset(from.getBeginOffset());
        setEndOffset(from.getEndOffset());
        setTokenSource(from.getTokenSource());
    }

    /**
     * Copy the location info given a start and end Node
     * @param start the start node
     * @param end the end node
     */
    default void copyLocationInfo(Node start, Node end) {
        setTokenSource(start.getTokenSource());
        if (getTokenSource() == null) setTokenSource(end.getTokenSource());
        setBeginOffset(start.getBeginOffset());
        setEndOffset(end.getEndOffset());
    }

    default void replace(Node toBeReplaced) {
        copyLocationInfo(toBeReplaced);
        Node parent = toBeReplaced.getParent();
        if (parent != null) {
           int index = parent.indexOf(toBeReplaced);
           parent.setChild(index, this);
        }
    }

    /**
     * Returns the first child of this node. If there is no such node, this returns
     * <code>null</code>.
     *
     * @return the first child of this node. If there is no such node, this returns
     *         <code>null</code>.
     */
    default Node getFirstChild() {
        return size() > 0 ? get(0) : null;
    }


     /**
     * Returns the last child of the given node. If there is no such node, this
     * returns <code>null</code>.
     *
     * @return the last child of the given node. If there is no such node, this
     *         returns <code>null</code>.
     */
    default Node getLastChild() {
        int count = size();
        return count > 0 ? get(count - 1): null;
    }

    default Node getRoot() {
        Node parent = this;
        while (parent.getParent() != null ) {
            parent = parent.getParent();
        }
        return parent;
    }

    default List<Node> descendants() {
        return descendants(Node.class, null);
    }

    default List<Node> descendants(Predicate<? super Node> predicate) {
        return descendants(Node.class, predicate);
    }

    default <T extends Node> List<T> descendants(Class<T> clazz) {
        return descendants(clazz, null);
    }

    default <T extends Node> List<T> descendants(Class<T> clazz, Predicate<? super T> predicate) {
       List<T> result = new ArrayList<>();
       for (int i = 0; i < size(); i++) {
           Node child = get(i);
           if (clazz.isInstance(child)) {
               T t = clazz.cast(child);
               if (predicate == null || predicate.test(t)) {
                   result.add(t);
               }
           }
           result.addAll(child.descendants(clazz, predicate));
       }
       return result;
    }

    default void dump(String prefix, PrintStream ps) {
        String output;

        if (this instanceof TerminalNode) {
            if (this.getType().isEOF()) {
                output = "EOF";
            }
            else if (this.getType().isInvalid()) {
                output = "Lexically Invalid Input:" + toString();
            }
            else {
                output = toString().trim();
            }
            output = String.format("%s: (%d, %d) - (%d, %d): %s",
                                   getClass().getSimpleName(),
                                   getBeginLine(), getBeginColumn(),
                                   getEndLine(), getEndColumn(),
                                   output);
        }
        else {
            output = String.format("<%s (%d, %d)-(%d, %d)>",
                                   getClass().getSimpleName(),
                                   getBeginLine(), getBeginColumn(),
                                   getEndLine(), getEndColumn());
        }
[#if settings.faultTolerant]
        if (this.isDirty()) {
            output += " (incomplete)";
        }
[/#if]
        if (output.length() > 0) {
            ps.println(prefix + output);
        }
        for (Node child : this) {
            child.dump(prefix + "  ", ps);
        }
    }

    default void dump(String prefix) {
        dump(prefix, System.out);
    }

    default void dump() {
        dump("");
    }
[#if settings.faultTolerant]

    default boolean isDirty() {
        return false;
    }

    void setDirty(boolean dirty);

[/#if]

    // NB: This default implementation is not thread-safe
    // If the node's children could change out from under you,
    // you could have a problem.
    default public ListIterator<Node> iterator() {
        return new ListIterator<Node>() {
            private int current = -1;
            private boolean justModified;

            public boolean hasNext() {
                return current + 1 < size();
            }

            public Node next() {
                justModified = false;
                return get(++current);
            }

            public Node previous() {
                justModified = false;
                return get(--current);
            }

            public void remove() {
                if (justModified) throw new IllegalStateException();
                removeChild(current);
                --current;
                justModified = true;
            }

            public void add(Node n) {
                if (justModified) throw new IllegalStateException();
                addChild(current + 1, n);
                justModified = true;
            }

            public boolean hasPrevious() {
                return current > 0;
            }

            public int nextIndex() {
                return current + 1;
            }

            public int previousIndex() {
                return current;
            }

            public void set(Node n) {
                setChild(current, n);
            }
        };
    }

    default List<Node> subList(int from, int to) {
        throw new UnsupportedOperationException();
    }

    default ListIterator<Node> listIterator() {
        return iterator();
    }

    default ListIterator<Node> listIterator(int i) {
        throw new UnsupportedOperationException();
    }

    default int indexOf(Object obj) {
        for (int i = 0; i< size(); i++) {
            if (get(i).equals(obj)) return i;
        }
        return -1;
    }

    default int lastIndexOf(Object obj) {
        for (int i = size() - 1; i >= 0; i--) {
            if (get(i).equals(obj)) return i;
        }
        return -1;
    }

    default boolean addAll(Collection<? extends Node> nodes) {
        throw new UnsupportedOperationException();
    }

    default boolean addAll(int i, Collection<? extends Node> nodes) {
        throw new UnsupportedOperationException();
    }

    default boolean containsAll(Collection<?> nodes) {
        throw new UnsupportedOperationException();
    }

    default boolean retainAll(Collection<?> nodes) {
        throw new UnsupportedOperationException();
    }

    default boolean removeAll(Collection<?> nodes) {
        throw new UnsupportedOperationException();
    }

    default <T> T[] toArray(T[] nodes) {
        return children().toArray(nodes);
    }

    default Object[] toArray() {
        return children().toArray();
    }

    default boolean contains(Object obj) {
        return indexOf(obj) >= 0;
    }

    default boolean isEmpty() {
        return size() == 0;
    }

    default void clear() {
        clearChildren();
    }

    static abstract public class Visitor {
        private static Map<Class<? extends Node.Visitor>, Map<Class<? extends Node>, Method>> mapLookup;
        private static final Method DUMMY_METHOD;
        static {
            try {
                // Use this just to represent no method found, since ConcurrentHashMap cannot contain nulls
                DUMMY_METHOD = Object.class.getMethod("toString");
            } catch (Exception e) {throw new RuntimeException(e);} // Never happens anyway.
            mapLookup = Collections.synchronizedMap(new HashMap<Class<? extends Node.Visitor>, Map<Class<? extends Node>, Method>>());
        }
        private Map<Class<? extends Node>, Method> methodCache;
        {
            this.methodCache = mapLookup.get(this.getClass());
            if (methodCache == null) {
                methodCache = new ConcurrentHashMap<Class<? extends Node>, Method>();
                mapLookup.put(this.getClass(), methodCache);
            }
        }
        protected boolean visitUnparsedTokens;

        private Method getVisitMethod(Node node) {
            Class<? extends Node> nodeClass = node.getClass();
            Method method = methodCache.get(nodeClass);
            if (method == null) {
                method = getVisitMethodImpl(nodeClass);
                methodCache.put(nodeClass, method);
            }
            return method;
        }

        // Find handler method for this node type. If there is none,
        // it checks for a handler for any explicitly marked interfaces
        // If necessary, it climbs the class hierarchy to superclasses
        private Method getVisitMethodImpl(Class<?> nodeClass) {
            if (nodeClass == null || !Node.class.isAssignableFrom(nodeClass)) return DUMMY_METHOD;
            try {
                Method m = this.getClass().getDeclaredMethod("visit", nodeClass);
                if (!Modifier.isPublic(nodeClass.getModifiers()) || !Modifier.isPublic(m.getModifiers())) {
                    m.setAccessible(true);
                }
                return m;
            } catch (NoSuchMethodException e) {}
            for (Class<?> interf : nodeClass.getInterfaces()) {
                if (Node.class.isAssignableFrom(interf) && !Node.class.equals(interf)) try {
                    Method m = this.getClass().getDeclaredMethod("visit", interf);
                    if (!Modifier.isPublic(interf.getModifiers()) || !Modifier.isPublic(m.getModifiers())) {
                        m.setAccessible(true);
                    }
                    return m;
                } catch (NoSuchMethodException e) {}
            }
            return getVisitMethodImpl(nodeClass.getSuperclass());
        }

        /**
         * Tries to invoke (via reflection) the appropriate visit(...) method
         * defined in a subclass. If there is none, it just calls the recurse() routine.
         * @param node the Node to "visit"
         */
        public void visit(Node node) {
            if (node == null) return;
            Method visitMethod = getVisitMethod(node);
            if (visitMethod == DUMMY_METHOD) {
                recurse(node);
            } else try {
                visitMethod.invoke(this, node);
            } catch (InvocationTargetException ite) {
                Throwable cause = ite.getCause();
                if (cause instanceof RuntimeException) {
                    throw (RuntimeException) cause;
                }
                throw new RuntimeException(ite);
            } catch (IllegalAccessException iae) {
                throw new RuntimeException(iae);
            }
        }

        /**
         * Just recurses over (i.e. visits) the node's children
         * @param node the node we are traversing
         */
        public void recurse(Node node) {
            if (node != null) {
                for (Node child : node.children(visitUnparsedTokens)) {
                    visit(child);
                }
            }
        }
    }
}
