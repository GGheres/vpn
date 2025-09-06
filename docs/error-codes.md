
# Error Codes Registry

| code     | where              | description                          | action                    |
|----------|--------------------|--------------------------------------|---------------------------|
| VPN-001  | xray_agent.sync    | node unreachable                     | retry + alert             |
| VPN-002  | xray_agent.reload  | xray reload failed                   | alert + manual check      |
| VPN-003  | config.render      | xray config rendering/write failed   | fail job + manual check   |
| TG-001   | telegram.api       | Telegram API timeout                 | retry                     |
| TG-002   | telegram.cmd       | unknown command                      | help reply                |
| BILL-001 | billing.webhook    | signature invalid                    | deny + log                |
| BILL-002 | billing.charge     | charge failed                        | retry + notify            |
| API-001  | api.auth           | invalid token / route not found      | 401/404                   |
| DB-001   | repo.query         | database error                       | retry read, fail write    |
