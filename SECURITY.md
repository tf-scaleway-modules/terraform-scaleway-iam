# Security

## What lands in state

| Data | Where | In state | Mitigation |
|------|-------|----------|------------|
| `api_keys[*].secret_key` | `api_keys` output (sensitive) | Yes, unless the key sets `secret_id` | Set `secret_id` to a Secret Manager secret: the provider stores the secret key as a secret version and leaves it out of state and outputs (`secret_key` is `null`). Enforce it with `require_api_key_secret_id = true`; `security_audit.api_keys_secret_in_state` lists the keys that still store it. Encrypt the state at rest and restrict access to it. |
| `user_details[*].email` | `user_details` output (sensitive) | Yes (the provider stores the email of every user) | The `users` output omits it; read `user_details` only where needed. Encrypt the state at rest and restrict access to it. |

The module creates no other secret. `secret_id` is an identifier, not a secret.

## Least privilege

The identity running Terraform needs `SecretManagerEditor` (to create secret versions) on the project of every secret referenced by `secret_id`, in addition to its IAM permissions. Grant it on that project only.

Adding or changing `secret_id` on an existing API key replaces the key (new access key and secret key): treat it as a rotation, key by key.
