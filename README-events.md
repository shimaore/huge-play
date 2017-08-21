Events
======

- Call-related messages are generated uniformly by `@report` and `@notify` methods;
- These methods both send their messages over `@cfg.statistics` with event name `report`.
- Call-center-related messages are generated uniformly by `call.report` and `agent.notify` methods in `middleware/client/queuer`;
- These methods both send their messages over `@cfg.statistics` with event name `queuer`.
- Messages are forwarded by `needy-toothpaste` to the local Redis server.
