Events
======

- Call-related messages are generated uniformly by `@report` and `@notify` methods;
- These methods both send their messages with event name `report`.
- Call-center-related messages are generated uniformly by `call.notify` and `agent.notify` methods in `middleware/client/queuer`;
- These methods both send their messages with event name `queuer`.
