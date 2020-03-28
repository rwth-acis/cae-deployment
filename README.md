# CAE Deployment

[![Docker image][docker-build-image]][docker-repo]

CAE Deployment Docker container is used to run CAE created application. It fetches latest artifact from given CAE Jenkins instance and run it.

## Usage
Docker image can be built with following command:
```
$ cd cae-deployment
$ docker build -t rwthacis/cae-deployment .
```

It can be run manually however it is not needed generally since it will be started by DockerJob of CAE Jenkins normally.

Following environment variable are needed to be passed during initialization:
* `JENKINS_URL`: Url address of CAE Jenkins instance
* `BUILD_JOB_NAME`: Name of build job which CAE Jenkins contains
* `DOCKER_URL`: Url address of deployment container

Following environment variables have default values however they can be changed during initialization:
* `MICROSERVICE_WEBCONNECTOR_PORT`: WebConnector port of las2peer backend service of deployed application
* `MICROSERVICE_PORT`: Port of las2peer backend service of deployed application
* `HTTP_PORT`: Port of server application which serves frontend of the deployed application

[docker-build-image]: https://img.shields.io/docker/cloud/build/rwthacis/cae-deployment
[docker-repo]: https://hub.docker.com/r/rwthacis/cae-deployment
