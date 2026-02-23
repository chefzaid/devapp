.PHONY: help install install-web test test-back test-front coverage coverage-back coverage-front build build-back build-front run-user run-order run-front

help:
	@echo "Common commands:"
	@echo "  make install         - install backend and frontend dependencies"
	@echo "  make test            - run backend and frontend tests"
	@echo "  make coverage        - run backend and frontend coverage commands"
	@echo "  make build           - build backend and frontend apps"
	@echo "  make run-user        - run user-app locally"
	@echo "  make run-order       - run order-app locally"
	@echo "  make run-front       - run frontend locally"

install: install-web
	mvn -q -DskipTests install

install-web:
	cd devapp-web && CYPRESS_INSTALL_BINARY=0 npm install

test: test-back test-front

test-back:
	mvn test

test-front:
	cd devapp-web && npm test

coverage: coverage-back coverage-front

coverage-back:
	mvn clean verify

coverage-front:
	cd devapp-web && npm run test:coverage

build: build-back build-front

build-back:
	mvn clean package -DskipTests

build-front:
	cd devapp-web && npm run build-prod

run-user:
	mvn spring-boot:run -pl user-app

run-order:
	mvn spring-boot:run -pl order-app

run-front:
	cd devapp-web && npm start
