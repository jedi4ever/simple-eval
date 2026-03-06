.PHONY: clean task eval
TESSL_WORKSPACE=patrickdebois

task:
	@echo "Completing the task..."
	@claude "complete the task describe in @evals/hello-world-typescript/task.md in the current directory"

local-judge: 
	@echo "Evaluating the solution against the criteria..."
	@claude "evaluate the solution against the criteria describe in @evals/hello-world-typescript/criteria.json"

eval:
	@echo "Evaluating the solution against the criteria..."
	./script/run-eval.sh @evals/hello-world-typescript

tessl-eval:
	@echo "Evaluating the solution against the criteria..."
	@tessl eval run --workspace ${TESSL_WORKSPACE} evals/hello-world-typescript

tessl-list:
	@echo "Listing the evaluations..."
	@tessl eval list --workspace ${TESSL_WORKSPACE}

clean:
	rm -rf ./src
	rm -rf ./dist
	rm package-lock.json
	rm package.json
	rm -rf ./node_modules
	rm tsconfig.json