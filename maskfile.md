# DevApp Task Commands

## help

```bash
echo "Common commands:"
echo "  mask install         - install backend and frontend dependencies"
echo "  mask test            - run backend and frontend tests"
echo "  mask coverage        - run backend and frontend coverage commands"
echo "  mask build           - build backend and frontend apps"
echo "  mask run-user        - run user-app locally"
echo "  mask run-order       - run order-app locally"
echo "  mask run-front       - run frontend locally"
```

## install

```bash
mask install-web
mvn -q -DskipTests install
```

## install-web

```bash
cd devapp-web && CYPRESS_INSTALL_BINARY=0 npm install
```

## test

```bash
mask test-back
mask test-front
```

## test-back

```bash
mvn test
```

## test-front

```bash
cd devapp-web && npm test
```

## coverage

```bash
mask coverage-back
mask coverage-front
```

## coverage-back

```bash
mvn clean verify
```

## coverage-front

```bash
cd devapp-web && npm run test:coverage
```

## build

```bash
mask build-back
mask build-front
```

## build-back

```bash
mvn clean package -DskipTests
```

## build-front

```bash
cd devapp-web && npm run build-prod
```

## run-user

```bash
mvn spring-boot:run -pl user-app
```

## run-order

```bash
mvn spring-boot:run -pl order-app
```

## run-front

```bash
cd devapp-web && npm start
```
