"""An implementation and demonstration of Bayesian Networks in Python.
"""

import cygraph as cg


class BayesianNetwork:
    """A bayesian network class capable of inneficient inference using
    the enumeration algorithm. Only capable of handling binary
    variables.
    """

    def __init__(self):
        self.graph = cg.graph(static=False, graph_=None, directed=True,
            vertices=[])

    def add_edge(self, A: str, B: str, conditional_probability: float):
        """Adds an edge to the network, representing the conditional
        proability between the two variables.

        Parameters
        ----------
        A: str
            The causing variable (parent).
        B: str
            The dependent variable (child).
        conditional_probability: float
            The probability that event A occurs given that event B
            occurs. P(A | B)
        """
        self.graph.add_edge(A, B, conditional_probability)

    def add_vertex(self, name: str, prior_probability: float):
        """Adds a vertex to the network, representing a new variable.

        Parameters
        ----------
        name: str
            The name of the variable.
        prior_probability: float
            The probability that the event represented by this variable
            will occur.
        """
        self.graph.add_vertex(name)
        self.graph.set_vertex_attribute(name, key="Prior Probability",
            val=prior_probability)

    def get_joint_probability(self, false_vars: list=[]) -> float:
        """Gets the joint probability of all the nodes in the network.

        Parameters
        ----------
        false_vars: list of str
            Variables that are treated as false instead of true (so that
            their prior probability is one minus what was inputted when
            they were added to the network.)

        Returns
        -------
        float
            The joint probability of all of the variables in the network
            being either true or false (depending on false_vars).
        """
        joint_probability = 1.0

        for variable in self.graph.vertices:
            variable_probability = 1.0

            false_var = variable in false_vars
            parents = self.graph.get_parents(variable)
            if parents:
                # Use conditional probability.
                for parent in parents:
                    conditional_probability = self.graph.get_edge_weight(
                        parent, variable)
                    variable_probability *= (
                        1 - conditional_probability if false_var
                        else conditional_probability)
            else:
                # Use prior probability.
                prior_probability = self.graph.get_vertex_attribute(
                    variable, "Prior Probability")
                variable_probability = (1 - prior_probability if false_var
                    else prior_probability)

            joint_probability *= variable_probability

        return joint_probability

    def marginalize_joint_probability(self, nuisance_variables: list) -> float:
        """Finds the joint probability of the network after summing out
        the nuisance variables.

        Parameters
        ----------
        nuisance_variables: list
            A list of variables to exclude from the joint probability
            using marginalization.

        Returns
        -------
        float
            The joint probability of the network after summing out each
            of the variables in `nuisance_variables`.
        """
        probability_sum = 0.0
        n_nuisance_variables = len(nuisance_variables)
        stack = [[]]
        while stack:
            var_states = stack.pop()
            if len(var_states) == n_nuisance_variables:
                # Base case: The code inside the final for-loop in the
                # nested for-loops of enumeration.
                probability_sum += self.get_joint_probability(
                    [var for var, state in zip(nuisance_variables, var_states)
                     if not state])
            else:
                for state in [True, False]:
                    stack.append(var_states + [state])

        return probability_sum

    def get_conditional_probability(self, A: str, B: str) -> float:
        """Calculates the conditional probability of a node being true given
        any other node.

        Parameters
        ----------
        A: str
            The causing variable (parent).
        B: str
            The dependent variable (child).

        Returns
        -------
        float
            The probability that event A occurs given that event B
            occurs. In mathematical notation, P(A | B)
        """
        # Calculate joint probability of distribution with only the
        # relevant variables.
        nuisance_variables = [var for var in self.graph.vertices
                              if var not in (A, B)]
        marginalized_joint_probability = \
            self.marginalize_joint_probability(nuisance_variables)

        return (marginalized_joint_probability
              / self.graph.get_vertex_attribute(B, "Prior Probability"))


if __name__ == '__main__':
    # Example from 3Blue1Brown video "Bayes theorem".
    bayesian_network = BayesianNetwork()
    # 1/21 chance Steve is a librarian.
    bayesian_network.add_vertex('L', 1 / 21)
    # 24 / 210 change Steve is shy.
    bayesian_network.add_vertex('S', 24 / 210)
    # 10% change Steve only wears white shirts.
    bayesian_network.add_vertex('W', 0.1)
    # 40% chance Steve is shy given that he is a librarian.
    bayesian_network.add_edge('L', 'S', 0.4)

    cond_prob_1 = bayesian_network.get_conditional_probability('L', 'S')
    print("The probability that Steve is a librarian given that he is shy: "
        f"{cond_prob_1}")