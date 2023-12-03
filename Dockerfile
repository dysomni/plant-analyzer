FROM public.ecr.aws/lambda/python:3.11

RUN pip install pipenv==2022.10.12

# Copy requirements.txt
COPY Pipfile ${LAMBDA_TASK_ROOT}
COPY Pipfile.lock ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN pipenv install --system --deploy --ignore-pipfile

# Copy function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}
COPY lib ${LAMBDA_TASK_ROOT}/lib

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_function.handler" ]