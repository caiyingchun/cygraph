#!python
#cython: language_level=3
"""A graph theory library implemented in Cython.

Examples
--------
>>> import cygraph as cg
>>> import cygraph.algorithms as alg
>>> G = cg.graph(vertices=list(range(4)))
>>> G.add_edge(1, 2)
>>> G.add_edge(2, 3)
>>> G.add_edge(3, 1)
>>> G.get_children(1)
{2, 3}
>>> alg.get_number_components(G)
2
"""

from .graph_ cimport Graph, DynamicGraph, StaticGraph


cpdef Graph graph(bint static=False, Graph graph_=None, bint directed=False,
        list vertices=[]):
    """Create an instance of a cygraph.Graph object.

    Parameters
    ----------
    static: bint, optional
        Whether to create a cygraph.StaticGraph or cygraph.DynamicGraph
        instance. Setting this to True will mean algorithms will mean
        all operations will run faster, but adding vertices after
        initialization will be slow.
    graph_: cygraph.Graph, optional
        A graph to create a copy of.
    directed: bint, optional
        Whether to create a directed graph (otherwise undirected).
    vertices: list, optional
        A list of the vertices in this graph.
    
    Returns
    -------
    cygraph.Graph
        A graph.
    """
    cdef dict kwargs = {
        'graph': graph_,
        'directed': directed,
        'vertices': vertices
    }
    if static:
        return StaticGraph(**kwargs)
    else:
        return DynamicGraph(**kwargs)