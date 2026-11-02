# Simulating `GET /oauth/v2/authorize`

For the Simulate tab of the Editor of `oauth-authorization`. The folder `examples/authorization/sharedflows` must be in
Settings, or the KVM, threat protection and CORS shared flows are not played.

## Fields

**Verb:** `GET`

**Path:**

```text
/oauth/v2/authorize?response_type=code&client_id=demo-app&redirect_uri=https://app.example.com/callback&scope=openid%20profile&state=xyz123&nonce=n-0S6&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256
```

**Request headers:**

```text
Host: api.example.com
```

**Variables set from outside** (what the KVMs and AccessEntity would give):

```text
idp.authorize_url=http://localhost:8766/authorize
idp.callback_url=https://api.example.com/oauth/v2/callback
idp.issuer=http://localhost:8766
idp.jwks_uri=http://localhost:8766/jwks
idp.transport=tls
idp.client_auth=client_secret_post
private.idp.client_id=broker-client
AccessEntity.AE-Authorize-App.content=<App><CallbackUrl>https://app.example.com/callback</CallbackUrl></App>
```

Leave the other fields as they are: this flow has no target.

## Expected result

`302 Found`, with a `Location` to the IdP holding `client_id=broker-client`, a generated `state` and `nonce=n-0S6`. The
route is `no-target`: the proxy answers itself.

## Variants

| Change | Result | Stops at |
|---|---|---|
| `redirect_uri=https://evil.example.com/cb` in the path | `400`, `invalid_request` | `RF-Invalid-Request` |
| Remove `code_challenge` from the path | `400`, `invalid_request` | `RF-Invalid-Request` |
| Policies to fail: `VA-Authorize-Client` | `401`, `invalid_client` | `AM-Error-Invalid-Client` |
| Policies to fail: `Q-Authorize-Client` | `429` | `AM-Error-Too-Many` |
