AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
LAMBDA_URL := $(shell terraform -chdir=tf output -raw function_url)
include .env
export

docker/build:
	docker build --platform linux/amd64 -t $(AWS_LAMBDA_NAME):latest .

docker/login:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

aws/create-repo:
	aws ecr create-repository --repository-name $(AWS_LAMBDA_NAME) --region us-east-1 --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE --region $(AWS_REGION)

docker/tag:
	docker tag $(AWS_LAMBDA_NAME):latest $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(AWS_LAMBDA_NAME):latest

docker/push: docker/tag
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(AWS_LAMBDA_NAME):latest

deploy: docker/build docker/push
	terraform -chdir=tf init -migrate-state \
		-backend-config="bucket=${TF_STATE_S3_BUCKET}" \
		-backend-config="dynamodb_table=${TF_STATE_DYNAMODB_TABLE}" \
		-backend-config="key=${AWS_LAMBDA_NAME}/terraform.tfstate"
	terraform -chdir=tf apply

env:
	printenv

unlock:
	terraform -chdir=tf init -migrate-state \
		-backend-config="bucket=${TF_STATE_S3_BUCKET}" \
		-backend-config="dynamodb_table=${TF_STATE_DYNAMODB_TABLE}" \
		-backend-config="key=${AWS_LAMBDA_NAME}/terraform.tfstate"
	terraform -chdir=tf force-unlock $(LOCK_ID)

generate:
	openssl rand -base64 64 | tr -dc '[:alnum:]'

FILE_DATA := $(shell cat ./examples/20231202144404-plants.json)

curl:
	curl "$(LAMBDA_URL)?start=2023-01-01&end=2024-01-01&id=1471b962-a0ea-4f0e-bb90-fec14d814b0a" -X POST -H "AUTH: $(TF_VAR_AUTH)" --data "$$FILE_DATA"
