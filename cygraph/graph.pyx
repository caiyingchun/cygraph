"""Implementation of StaticGraph and DynamicGraph classes.
"""

import copy
import functools
import warnings

cimport numpy as np
import numpy as np


cdef type DTYPE = np.float64
ctypedef np.float64_t DTYPE_t


NOT_IMPLEMENTED = ("%s is not implemented for "
    "cygraph.Graph instance. Try it with cygraph.StaticGraph or "
    "cygraph.DynamicGraph.")


cdef class Graph:
    """A semi-abstract base graph class.

    Semi-abstract because anything that involves the adjacency matrix
    is not implemented, and therefore this class is not meant to be
    used for instantiating objects. The reason why those methods are
    even in this class is so that downcasting still works because of
    early binding.
    """

    def __cinit__(self, *args, **kwargs):

        cdef Graph graph = None

        if len(args) == 3:
            graph = <Graph?>args[3]

        if "graph" in kwargs:
            graph = kwargs["graph"]

        if len(args) == 1:
            if isinstance(args[0], Graph):
                graph = args[0]

        if graph is not None:
            self._vertex_attributes = copy.deepcopy(graph._vertex_attributes)
            self._edge_attributes = copy.deepcopy(graph._edge_attributes)

            self.directed = bool(graph.directed)
            self.vertices = graph.vertices[:]

    cdef int _get_vertex_int(self, object vertex) except -1:
        """Returns the int corresponding to a vertex.

        Parameters
        ----------
        vertex
            A vertex in the graph.

        Returns
        -------
        int
            The integer corresponding to `vertex`.
        """
        try:
            return self.vertices.index(vertex)
        except ValueError:
            raise ValueError(f"{vertex} is not in graph.")

    cpdef void add_vertex(self, object v) except *:
        raise NotImplementedError(NOT_IMPLEMENTED % "add_vertex")

    cpdef void remove_vertex(self, object v) except *:
        raise NotImplementedError(NOT_IMPLEMENTED % "remove_vertex")

    cpdef void set_vertex_attribute(self, object vertex, object key, object val) except *:
        """Sets an attribute to a vertex.

        Parameters
        ----------
        vertex
            A vertex in the graph.
        key
            The name of the attribute. Must be of hashable type.
        val
            The value of the attribute.
        """
        try:
            self._vertex_attributes[vertex][key] = val
        except KeyError:
            raise ValueError(f"{vertex} is not in graph.")

    cpdef object get_vertex_attribute(self, object vertex, object key):
        """Gets an attribute of a vertex.

        Parameters
        ----------
        vertex
            A vertex in the graph.
        key
            The name of the attribute. Must be of hashable type.

        Returns
        -------
        The value of the attribute.
        """
        cdef dict vertex_attributes
        try:
            vertex_attributes = self._vertex_attributes[vertex]
        except KeyError:
            raise ValueError(f"{vertex} is not in graph.")
        return vertex_attributes[key]

    cpdef bint has_vertex(self, object vertex) except *:
        """Returns whether or not a vertex is in this graph.

        Parameters
        ----------
        vertex
            A valid vertex (hashable type).

        Returns
        -------
        bint
            Whether or not `vertex` is in this graph.
        """
        return vertex in self.vertices

    cpdef void add_edge(self, object v1, object v2, double weight=1.0) except *:
        raise NotImplementedError(NOT_IMPLEMENTED % "add_edge")

    cpdef void remove_edge(self, object v1, object v2) except *:
        raise NotImplementedError(NOT_IMPLEMENTED % "remove_edge")

    cpdef void set_edge_attribute(self, tuple edge, object key, object val) except *:
        """Sets an attribute to an edge.

        Parameters
        ----------
        edge: tuple
            An edge in the graph in the form (v1, v2).
        key
            The name of the attribute. Must be of hashable type.
        val
            The value of the attribute.
        """
        try:
            self._edge_attributes[edge][key] = val
        except KeyError:
            if self.directed:
                raise ValueError(f"{edge} is not in graph.")
            else:
                try:
                    self._edge_attributes[(edge[1], edge[0])][key] = val
                except KeyError:
                    raise ValueError(f"{edge} is not in graph.")

    cpdef object get_edge_attribute(self, tuple edge, object key):
        """Gets an attribute of an edge.

        Parameters
        ----------
        edge: tuple
            An edge in the graph in the form (v1, v2).
        key
            The name of the attribute. Must be of hashable type.

        Returns
        -------
        The value of the attribute.
        """
        cdef dict edge_attributes
        try:
            edge_attributes = self._edge_attributes[edge]
        except KeyError:
            if self.directed:
                raise ValueError(f"{edge} is not in graph.")
            else:
                try:
                    edge_attributes = self._edge_attributes[(edge[1], edge[0])]
                except KeyError:
                    raise ValueError(f"{edge} is not in graph.")
        return edge_attributes[key]

    cpdef double get_edge_weight(self, object v1, object v2) except *:
        raise NotImplementedError(NOT_IMPLEMENTED % "get_edge_weight")

    cpdef set get_children(self, object vertex):
        raise NotImplementedError(NOT_IMPLEMENTED % "get_children")
    
    cpdef set get_parents(self, object vertex):
        raise NotImplementedError(NOT_IMPLEMENTED % "get_parents")

    @property
    def edges(self):
        raise NotImplementedError(NOT_IMPLEMENTED % "edges")

    @property
    def edge_attributes(self):
        return self._edge_attributes

    @property
    def vertex_attributes(self):
        return self._vertex_attributes

    def __iter__(self):
        return iter(self.vertices)

    def __len__(self):
        return len(self.vertices)

    def __repr__(self):
        return f"<{self.__class__.__name__}; vertices={self.vertices!r}; edges={self.edges!r}>"

    def __str__(self):
        return str(np.array(self._adjacency_matrix))


cdef class StaticGraph(Graph):
    """A class representing a graph data structure.

    This is a directed graph class, although it will function as an
    undirected graph by creating directed edges both ways between two
    vertices. This class contains only basic functionality; algorithms
    are implemented externally.

    Adding vertices to a StaticGraph is relatively slow, expecially for
    already large graphs. If you are going to be adding lots of
    vertices to your graph, consider using cygraph.DynamicGraph.

    Parameters
    graph: cygraph.Graph, optional
        A graph to create a copy of.
    directed: bint, optional
        Whether or not the graph contains directed edges.
    vertices: list, optional
        A list of vertices (can be any hashable type).

    Note that `directed` and `vertices` args will be ignored if
    `graph` is not None.

    Attributes
    ----------
    directed: bint
        Whether or not the graph contains directed edges.
    vertices: list
        The vertices in this graph.
    edges: set
        Tuples contianing the two vertices of each edge.
    edge_attribtues: dict
        Maps (v1, v2) tuples to dicts mapping edge attribute keys to
        corresponding values.
    vertex_attribtues: dict
        Maps vertices to dicts mapping vertex attribute keys to
        corresponding values.
    """

    def __cinit__(self, Graph graph=None, bint directed=False, list vertices=[]):

        cdef int size
        cdef object v

        if graph is not None:

            size = len(graph.vertices)
            self._adjacency_matrix = np.full((size, size), np.nan, dtype=DTYPE)
            self._adjacency_matrix_view = self._adjacency_matrix

            for edge in graph.edges:
                self.add_edge(edge[0], edge[1])

        else:
            self._vertex_attributes = {}
            self._edge_attributes = {}

            self.directed = directed
            self.vertices = list(vertices)

            # Map vertex names to numbers and vice versa.
            for v in self.vertices:
                self._vertex_attributes[v] = {}

            # Create adjacency matrix.
            size = len(self.vertices)
            self._adjacency_matrix = np.full((size, size), np.nan, dtype=DTYPE)
            self._adjacency_matrix_view = self._adjacency_matrix

    cpdef void add_edge(self, object v1, object v2, DTYPE_t weight=1.0) except *:
        """Adds edge to graph between two vertices with a weight.

        Parameters
        ----------
        v1
            One of the edge's vertices.
        v2
            One of the edge's vertices.
        weight: np.float64, optional
            The weight of the edge.
        """
        cdef int u = self._get_vertex_int(v1)
        cdef int v = self._get_vertex_int(v2)

        self._edge_attributes[(v1, v2)] = {}

        self._adjacency_matrix_view[u][v] = weight
        if not self.directed:
            self._adjacency_matrix_view[v][u] = weight

    cpdef void remove_edge(self, object v1, object v2) except *:
        """Removes an edge between two vertices in this graph.

        Parameters
        ----------
        v1
            One of the edge's vertices.
        v2
            One of the edge's vertices.
        """
        cdef int u = self._get_vertex_int(v1)
        cdef int v = self._get_vertex_int(v2)

        if np.isnan(self._adjacency_matrix_view[u][v]):
            warnings.warn("Attempting to remove edge that doesn't exist.")
        else:
            self._adjacency_matrix_view[u][v] = np.nan
            if not self.directed:
                self._adjacency_matrix_view[v][u] = np.nan

    cpdef bint has_edge(self, object v1, object v2) except *:
        """Returns whether or not an edge exists in this graph.

        Parameters
        ----------
        v1
            First vertex of the edge.
        v2
            Second vertex of the edge.

        Returns
        -------
        bint
            Whether or not edge is in graph.
        """
        cdef int u, v
        try:
            u = self.vertices.index(v1)
            v = self.vertices.index(v2)
        except ValueError:
            return False

        return not np.isnan(self._adjacency_matrix_view[u][v])

    cpdef DTYPE_t get_edge_weight(self, object v1, object v2) except *:
        """Returns the weight of the edge between vertices v1 and v2.

        Parameters
        ----------
        v1
            One of the edge's vertices.
        v2
            One of the edge's vertices.

        Returns
        -------
        np.float64
            The weight of the edge between v1 and v2.
        """
        cdef int u = self._get_vertex_int(v1)
        cdef int v = self._get_vertex_int(v2)
        cdef DTYPE_t weight = self._adjacency_matrix_view[u][v]
        if not np.isnan(weight):
            return weight
        else:
            raise ValueError(f"There is no edge ({v1}, {v2}) in graph.")

    cpdef void add_vertex(self, object v) except *:
        """Adds vertex to the graph.

        Parameters
        ----------
        v
            A vertex of any hashable type.
        """
        cdef int vertex_number = len(self.vertices)
        cdef np.ndarray new_row, new_column

        self._vertex_attributes[v] = {}

        if v in self.vertices:
            raise ValueError(f"{v} is already in graph")
        else:
            # Map vertex name to number.
            self.vertices.append(v)

            if vertex_number == 0:
                self._adjacency_matrix = np.full((1, 1), np.nan, dtype=DTYPE)
            else:
                # Add new row.
                new_row = np.full((1, vertex_number), np.nan, dtype=DTYPE)
                self._adjacency_matrix = \
                    np.append(self._adjacency_matrix, new_row, axis=0)

                # Add new column.
                new_column = np.full((vertex_number + 1, 1), np.nan, dtype=DTYPE)
                self._adjacency_matrix = \
                    np.append(self._adjacency_matrix, new_column, axis=1)

    cpdef void remove_vertex(self, object v) except *:
        """Removes a vertex from this graph.

        Parameters
        ----------
        v
            A vertex in this graph.
        """
        cdef int u = self._get_vertex_int(v)

        self.vertices.remove(v)
        np.delete(self._adjacency_matrix, u, axis=1)  # Delete column.
        np.delete(self._adjacency_matrix, u, axis=0)  # Delete row.

    cpdef set get_children(self, object v):
        """Returns the names of all the child vertices of a given
        vertex. Equivalent to neighbors if graph is undirected.

        Parameters
        ----------
        v
            A vertex in the graph.

        Returns
        -------
        set
            The child vertices of `v`.
        """
        cdef set children = set()
        cdef int u, w

        w = self._get_vertex_int(v)

        for u in range(len(self.vertices)):
            if not np.isnan(self._adjacency_matrix_view[w][u]):
                children.add(self.vertices[u])

        return children
    
    cpdef set get_parents(self, object v):
        """Returns the parents (aka "in-neighbors") of a given vertex.
        Equivalent to get_children in undirected graphs. 

        Parameters
        ----------
        v
            A vertex in the graph.
        
        Returns
        -------
        set
            The parent vertices of `v`.
        """
        cdef set parents = set()
        cdef int u, w

        w = self._get_vertex_int(v)

        for u in range(len(self.vertices)):
            if not np.isnan(self._adjacency_matrix_view[u][w]):
                parents.add(self.vertices[u])

        return parents

    @property
    def edges(self):
        cdef int u, v, n_vertices
        cdef set edges = set()
        cdef tuple new_edge, existing_edge
        cdef bint edge_found
        cdef DTYPE_t edge_weight

        n_vertices = len(self.vertices)

        if self.directed:
            for u in range(n_vertices):
                for v in range(n_vertices):
                    edge_weight = self._adjacency_matrix_view[u][v]
                    if not np.isnan(edge_weight):
                        edges.add(
                            (self.vertices[u],
                             self.vertices[v],
                             edge_weight
                            )
                        )
        else:
            for u in range(n_vertices):
                for v in range(n_vertices):
                    edge_weight = self._adjacency_matrix_view[u][v]
                    if not np.isnan(edge_weight):
                        # Edge exists. Add it if it hasn't already been found.
                        new_edge = (
                            self.vertices[u],
                            self.vertices[v],
                            edge_weight
                        )
                        edge_found = False
                        for existing_edge in edges:
                            if (    existing_edge[0] == new_edge[1]
                                    and existing_edge[1] == new_edge[0]):
                                edge_found = True
                                break
                        if edge_found:
                            continue
                        else:
                            edges.add(new_edge)

        return edges

    def __copy__(self):
        cdef StaticGraph new_graph = \
            StaticGraph(directed=self.directed, vertices=self.vertices)

        # Add edges and edge attributes.
        cdef tuple edge
        cdef object key
        for edge in self.edges:
            new_graph.add_edge(*edge)
            for key in self._edge_attributes[edge]:
                new_graph.set_edge_attribute(
                    edge, key, self._edge_attributes[edge][key])

        # Add vertex attributes.
        cdef object vertex
        for vertex in self.vertices:
            for key in self._vertex_attributes[vertex]:
                new_graph.set_vertex_attribtue(
                    vertex, key, self._vertex_attributes[vertex][key])

        return new_graph


cdef class DynamicGraph(Graph):
    """A class representing a graph data structure.

    This is a directed graph class, although it will function as an
    undirected graph by creating directed edges both ways between two
    vertices. This class contains only basic functionality; algorithms
    are implemented externally.

    Adding vertices to a graph is faster than with a StaticGraph, but
    overall performance (especially for operations like getting children
    and getting edge weights)is comprimised.

    Parameters
    ----------
    graph: cygraph.Graph, optional
        A graph to create a copy of.
    directed: bint, optional
        Whether or not the graph contains directed edges.
    vertices: list, optional
        A list of vertices (can be any hashable type).

    Note that `directed` and `vertices` args will be ignored if
    `graph` is not None.

    Attributes
    ----------
    directed: bint
        Whether or not the graph contains directed edges.
    vertices: list
        The vertices in this graph.
    edges: set
        Tuples contianing the two vertices of each edge.
    edge_attribtues: dict
        Maps (v1, v2) tuples to dicts mapping edge attribute keys to
        corresponding values.
    vertex_attribtues: dict
        Maps vertices to dicts mapping vertex attribute keys to
        corresponding values.
    """

    def __cinit__(self, Graph graph=None, bint directed=False, list vertices=[]):

        cdef int size

        cdef int i
        cdef object v

        if graph is not None:

            size = len(graph.vertices)
            self._adjacency_matrix = []
            for i in range(size):
                self._adjacency_matrix.append([])
                for _ in range(size):
                    self._adjacency_matrix[i].append(None)

            for edge in graph.edges:
                self.add_edge(edge[0], edge[1])

        else:
            self._vertex_attributes = {}
            self._edge_attributes = {}

            self.directed = directed
            self.vertices = list(vertices)

            # Map vertex names to numbers and vice versa.
            for v in self.vertices:
                self._vertex_attributes[v] = {}

            # Create adjacency matrix.
            size = len(self.vertices)
            self._adjacency_matrix = []
            for i in range(size):
                self._adjacency_matrix.append([])
                for _ in range(size):
                    self._adjacency_matrix[i].append(None)

    cpdef void add_edge(self, object v1, object v2, double weight=1.0) except *:
        """Adds edge to graph between two vertices with a weight.

        Parameters
        ----------
        v1
            One of the edge's vertices.
        v2
            One of the edge's vertices.
        weight: float, optional
            The weight of the edge.
        """
        cdef int u = self._get_vertex_int(v1)
        cdef int v = self._get_vertex_int(v2)

        self._edge_attributes[(v1, v2)] = {}

        self._adjacency_matrix[u][v] = weight
        if not self.directed:
            self._adjacency_matrix[v][u] = weight

    cpdef void remove_edge(self, object v1, object v2) except *:
        """Removes an edge between two vertices in this graph.

        Parameters
        ----------
        v1
            One of the edge's vertices.
        v2
            One of the edge's vertices.
        """
        cdef int u = self._get_vertex_int(v1)
        cdef int v = self._get_vertex_int(v2)

        if self._adjacency_matrix[u][v] is None:
            warnings.warn("Attempting to remove edge that doesn't exist.")
        else:
            self._adjacency_matrix[u][v] = None
            if not self.directed:
                self._adjacency_matrix[v][u] = None

    cpdef bint has_edge(self, object v1, object v2) except *:
        """Returns whether or not an edge exists in this graph.

        Parameters
        ----------
        v1
            First vertex of the edge.
        v2
            Second vertex of the edge.

        Returns
        -------
        bint
            Whether or not edge is in graph.
        """
        cdef int u, v
        try:
            u = self.vertices.index(v1)
            v = self.vertices.index(v2)
        except ValueError:
            return False

        return self._adjacency_matrix[u][v] is not None

    cpdef double get_edge_weight(self, object v1, object v2) except *:
        """Returns the weight of the edge between vertices v1 and v2.

        Parameters
        ----------
        v1
            One of the edge's vertices.
        v2
            One of the edge's vertices.

        Returns
        -------
        float
            The weight of the edge between v1 and v2.
        """
        cdef int u = self._get_vertex_int(v1)
        cdef int v = self._get_vertex_int(v2)
        weight = self._adjacency_matrix[u][v]
        if weight is not None:
            return weight
        else:
            raise ValueError("edge ({v1}, {v2}) is not in graph.")

    cpdef void add_vertex(self, object v) except *:
        """Adds vertex to the graph.

        Parameters
        ----------
        v
            A vertex of any hashable type.
        """
        cdef int vertex_number, i
        cdef list new_row

        self._vertex_attributes[v] = {}

        if v in self.vertices:
            raise ValueError(f"{v} is already in graph")
        else:
            # Map vertex name to number.
            vertex_number = len(self.vertices)
            self.vertices.append(v)

            # Add new row.
            new_row = [None for _ in range(vertex_number + 1)]
            self._adjacency_matrix.append(new_row)

            # Add new column.
            for i in range((len(self._adjacency_matrix) - 1)):
                self._adjacency_matrix[i].append(None)

    cpdef void remove_vertex(self, object v) except *:
        """Removes a vertex from this graph.

        Parameters
        ----------
        v
            A vertex in this graph.
        """
        cdef int u = self._get_vertex_int(v)

        self.vertices.remove(v)

        # Delete row and column from adjacency matrix.
        self._adjacency_matrix.pop(u)
        cdef list row
        for row in self._adjacency_matrix:
            row.pop(u)

    cpdef set get_children(self, object v):
        """Returns the names of all the child vertices of a given
        vertex. Equivalent to neighbors if graph is undirected.

        Parameters
        ----------
        v
            A vertex in the graph.

        Returns
        -------
        set
            The child vertices of `v`.
        """
        cdef set children = set()
        cdef int u, w

        w = self._get_vertex_int(v)

        for u in range(len(self.vertices)):
            if self._adjacency_matrix[w][u] is not None:
                children.add(self.vertices[u])

        return children

    cpdef set get_parents(self, object v):
        """Returns the parents (aka "in-neighbors") of a given vertex.
        Equivalent to get_children in undirected graphs. 

        Parameters
        ----------
        v
            A vertex in the graph.
        
        Returns
        -------
        set
            The parent vertices of `v`.
        """
        cdef set parents = set()
        cdef int u, w

        w = self._get_vertex_int(v)

        for u in range(len(self.vertices)):
            if self._adjacency_matrix[u][w] is not None:
                parents.add(self.vertices[u])

        return parents

    @property
    def edges(self):
        cdef int u, v, n_vertices
        cdef set edges = set()
        cdef tuple new_edge, existing_edge
        cdef bint edge_found
        cdef object edge_weight  # Can also be NoneType.

        n_vertices = len(self.vertices)

        if self.directed:
            for u in range(n_vertices):
                for v in range(n_vertices):
                    edge_weight = self._adjacency_matrix[u][v]
                    if edge_weight is not None:
                        edges.add(
                            (self.vertices[u],
                             self.vertices[v],
                             edge_weight)
                        )
        else:
            for u in range(n_vertices):
                for v in range(n_vertices):
                    edge_weight = self._adjacency_matrix[u][v]
                    if edge_weight is not None:
                        # Edge exists. Add it if it hasn't already been found.
                        new_edge = (
                            self.vertices[u],
                            self.vertices[v],
                            edge_weight
                        )
                        edge_found = False
                        for existing_edge in edges:
                            if (    existing_edge[0] == new_edge[1]
                                    and existing_edge[1] == new_edge[0]):
                                edge_found = True
                                break
                        if edge_found:
                            continue
                        else:
                            edges.add(new_edge)
        return edges

    def __copy__(self):
        cdef DynamicGraph new_graph = \
            DynamicGraph(directed=self.directed, vertices=self.vertices)

        # Add edges and edge attributes.
        cdef tuple edge
        cdef object key
        for edge in self.edges:
            new_graph.add_edge(*edge)
            for key in self._edge_attributes[edge]:
                new_graph.set_edge_attribute(
                    edge, key, self._edge_attributes[edge][key])

        # Add vertex attributes.
        cdef object vertex
        for vertex in self.vertices:
            for key in self._vertex_attributes[vertex]:
                new_graph.set_vertex_attribtue(
                    vertex, key, self._vertex_attributes[vertex][key])

        return new_graph