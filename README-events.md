Events
======

- Call-related messages are generated uniformly by `@report` and `@notify` methods;
- Call-center-related messages are generated uniformly by `call.notify` and `agent.notify` methods in `middleware/client/queuer`;
- Messages are forwarded by `needy-toothpaste` to the local Redis server.
