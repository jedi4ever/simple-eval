# Simple evals
The purpose of this project is to explain how to use Tessl's project evals.

## Scenario
- Task: 
    - We ask Claude to generate a hello world with a greeter endpoint. 
    - see <evals/hello-world-typescript/task.md>
- Context: 
    - In our `CLAUDE.md` we specified that all endpoints should be like `/awesome/<service>`
    - Code generated should be in the `src` directory
    - see full <CLAUDE.md>
- Criteria:
    - check if files were indeed created in `src`
    - check if is has a `/awesome/greeter` endpoint
    - check if the endpoint responds by using curl
    - see full <evals/hello-world-typescript/criteria.json>
- Base:
    - we specify our repo commit state on which it should execute the task
    - see <evals/hello-world-typescript/scenario.json>

## Testing the scenario locally
- We want to run the scenario with and without the context (CLAUDE.md)
- We do two runs: one with the context and one without (Baseline)

- We use `git worktree` to checkout the specific commit in a temporary directory
- We simply ask claude to execute the `task.md` in the worktree
- And then ask it to check the criteria from the scenario from `criteria.json`
- This is done with and without context
- After each run , a report is written
- And at the end Claude will compare it

A helper script is provided in `script/run-eval.sh`: 
- `./run-eval.sh evals/hello-world-typescript/` would run the scenario

Once Claude is done , just exit (CTRL-D twice) and it will continue

## Running in on Tessl
- Now we don't want to keep running these tests on our laptop, let's move them to Tessl.
- In order to Tessl to reach them:
    - you need to have a Tessl login
    - connect your Github account
    - know your workspace: `tessl workspace list`

- Now simple run `tessl eval run evals/hello-world-typescript` jedi4ever/simple-evals
- And wait for the results !!!