# Connect Four w/ MCTS AI [![CircleCI](https://circleci.com/gh/rjdellecese/connect_four.svg?style=svg)](https://circleci.com/gh/rjdellecese/connect_four) [![Coverage Status](https://coveralls.io/repos/github/rjdellecese/connect_four/badge.svg?branch=master)](https://coveralls.io/github/rjdellecese/connect_four?branch=master)

This is an implementation of John Tromp's very efficient Connect Four board logic code (read more about it [here](https://tromp.github.io/c4/c4.html)), coupled with a [Monte Carlo Tree Search](https://en.wikipedia.org/wiki/Monte_Carlo_tree_search) (MCTS) "AI" and a CLI for playing against it in the terminal.

The Monte Carlo Tree Search uses the [UCT algorithm](https://en.wikipedia.org/wiki/Monte_Carlo_tree_search#Exploration_and_exploitation) in the selection phase, and uniformly random moves in the simulation phase. It rebuilds the whole tree on each move, and doesn't employ any parallelization strategies while searching. Even so, it plays very well!

## Play against it

To play against it in your browser, right now, you can use Gitpod to launch a temporary dev environment containing a terminal with the CLI running by clicking on the badge below.

[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/rjdellecese/connect_four_umbrella)

## Setting up the project

1. Make sure you have Elixir and Erlang installed (you can find the required versions in the `.tool-versions` file)
2. Clone the repo

    ```bash
    git clone https://github.com/rjdellecese/connect_four.git
    cd connect_four
    ```

3. From the root of the project, download the dependencies

    ```bash
    mix deps.get
    ```

### Tests

Run the tests with

```bash
mix test
```

### CLI

To play against the MCTS AI, `cd` into the CLI app, build the escript executable, and then run it

```bash
cd apps/cli
mix escript.build
./cli
```

## Questions?

If you have any questions about how any of this works, please feel free to open an issue and I'll be happy to respond!
