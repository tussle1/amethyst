# security model

- authorization is enforced on the server using user ids
- every remote action is rate limited and validated
- movement values are clamped server-side
- teleport destinations are a fixed allowlist
- vehicle spawning is limited to templates stored by the experience owner
- vehicle speed changes apply only to a vehicle spawned for the requesting player
- training target discovery only reads models tagged AmethystTrainingDummy
- no client-side request can target another live player's character for combat actions

Replace the placeholder user id in the server script before testing. Never treat client-side interface visibility as authorization.
