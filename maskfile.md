# DevApp Task Commands

## help

```bash
echo "Common commands:"
echo "  mask install [back|front|all]  - install dependencies"
echo "  mask test [back|front|all]     - run tests"
echo "  mask coverage [back|front|all] - run coverage commands"
echo "  mask build [back|front|all]    - build apps"
echo "  mask run [all|user|order|front] - run apps (default: all)"
```

## install

```bash
target="${1:-all}"
. ./mask-common.sh
use_java_21_if_available
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
. ./mask-common.sh
use_java_21_if_available
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
. ./mask-common.sh
use_java_21_if_available
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
. ./mask-common.sh
use_java_21_if_available
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
target="${1:-all}"
. ./mask-common.sh
use_java_21_if_available
if [ "$target" = "user" ]; then
  mvn spring-boot:run -pl user-app
elif [ "$target" = "order" ]; then
  mvn spring-boot:run -pl order-app
elif [ "$target" = "front" ]; then
  cd devapp-web && npm start
else
  STARTUP_CHECK_DELAY=1
  mvn spring-boot:run -pl user-app &
  USER_PID=$!
  sleep "$STARTUP_CHECK_DELAY"
  if ! kill -0 "$USER_PID" 2>/dev/null; then
    echo "Failed to start user-app. Check logs and ensure port 8080 is available."
    exit 1
  fi
  mvn spring-boot:run -pl order-app &
  ORDER_PID=$!
  sleep "$STARTUP_CHECK_DELAY"
  if ! kill -0 "$ORDER_PID" 2>/dev/null; then
    echo "Failed to start order-app. Check logs and ensure port 8081 is available."
    kill "$USER_PID" 2>/dev/null || true
    exit 1
  fi
  cleanup() {
    for pid in "$USER_PID" "$ORDER_PID" "$FRONT_PID"; do
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
      fi
    done
  }
  trap cleanup EXIT INT TERM
  cd devapp-web && npm start &
  FRONT_PID=$!
  wait "$FRONT_PID"
fi
```
