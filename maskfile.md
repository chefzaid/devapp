# DevApp Task Commands

## help

```bash
echo "Common commands:"
echo "  mask install [back|front|all]  - install dependencies"
echo "  mask test [back|front|all]     - run tests"
echo "  mask coverage [back|front|all] - run coverage commands"
echo "  mask build [back|front|all]    - build apps"
echo "  mask run [user|order|front]    - run one app"
```

## install

```bash
target="${1:-all}"
if [ "$target" = "back" ]; then
  mvn -q -DskipTests install
elif [ "$target" = "front" ]; then
  cd devapp-web && CYPRESS_INSTALL_BINARY=0 npm install
else
  cd devapp-web && CYPRESS_INSTALL_BINARY=0 npm install && cd ..
  mvn -q -DskipTests install
fi
```

## test

```bash
target="${1:-all}"
if [ "$target" = "back" ]; then
  mvn test
elif [ "$target" = "front" ]; then
  cd devapp-web && npm test
else
  mvn test && cd devapp-web && npm test
fi
```

## coverage

```bash
target="${1:-all}"
if [ "$target" = "back" ]; then
  mvn clean verify
elif [ "$target" = "front" ]; then
  cd devapp-web && npm run test:coverage
else
  mvn clean verify && cd devapp-web && npm run test:coverage
fi
```

## build

```bash
target="${1:-all}"
if [ "$target" = "back" ]; then
  mvn clean package -DskipTests
elif [ "$target" = "front" ]; then
  cd devapp-web && npm run build-prod
else
  mvn clean package -DskipTests && cd devapp-web && npm run build-prod
fi
```

## run

```bash
target="${1:-front}"
if [ "$target" = "user" ]; then
  mvn spring-boot:run -pl user-app
elif [ "$target" = "order" ]; then
  mvn spring-boot:run -pl order-app
else
  cd devapp-web && npm start
fi
```
