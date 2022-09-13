# README

## Dev steps

1. Create partner account
2. Create custom/manual app
3. Save API secret key and API key for the app in `.env`:
```sh
SHOPIFY_API_KEY=
SHOPIFY_API_SECRET=
```
4. Install and run Cloudflared:
```sh
brew install cloudflare/cloudflare/cloudflared
cloudflared tunnel --url http://localhost:3000
```
5. Set the cloudflared host in `.env`:
```sh
HOST=https://random-words.trycloudflare.com
```
6. Set the cloudflared host as app URL and redirect URL in partners dashboard. redirect URL should end with /auth/shopify/callback
