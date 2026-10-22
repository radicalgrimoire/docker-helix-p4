# Helix Authentication Service (trial)

Starts the image built from [build/helix-auth-svc](../build/helix-auth-svc) on `http://localhost:3000` with no extra setup:

```bash
docker compose up -d
```

Without an identity provider, logins will not succeed. To try SAML, set variables on the command line or in the shell:

```bash
SVC_BASE_URI=https://has.example.com:3000 \
SAML_IDP_METADATA_URL=<federation metadata URL> \
TRUST_PROXY=<proxy IP> \
docker compose up -d
```

`SAML_SP_ENTITY_ID` (default `dev-auth`) is also overridable. `SAML_NAMEID_FORMAT` and `SAML_AUTHN_CONTEXT` from the previous deployment can be added to the `environment:` section when needed.
