# RateLimiter

This Elixir application accepts messages via an HTTP endpoint and processes the messages in the order that they are received, and no more than one per second. The application should be able to handle multiple queues based on a parameter passed into the HTTP endpoint.

1. [x] The application is a simple Plug based web server.
2. [x] The application has an HTTP endpoint at the path `/receive-message` which accepts a GET request with the query string parameters: `queue` (string), `message` (string).
3. [x] The application will accept messages as quickly as they come in and return a 200 status code.
4. [x] The application will "process" the messages by printing the message text to the terminal.    
    - [x] However for each queue, the application should only "process" one message a second, no matter how quickly the messages are submitted to the HTTP endpoint.
5. [x] Tests that verifies messages are only processed one per second.

## Caveats

- `RateLimiter` was made a singleton to make the API easier (no need to pass `pid`). This involves a little workaround when testing. `@FIXME`.
- Each queues could be individual `GenServer`, and it could handle better under big load. However, this involves `Registry` lookup, and it may increase the response time of the web handler. Therefore, all queues are kept and looked up through a `Map`. The performance and limitation on number of queues depend on `Map`.
- With the above setup, there can be race condition when two messages are handled at the exact same time. Both of the handlers will need to update the queue, thus updating the internal state of `RateLimiter`. Only one can win. Having one process per queue would make it much easier and should be the right way to do.