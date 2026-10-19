-- Oferta inicial de VIP por anúncio (editável no painel em Recompensas).
-- amount = horas de VIP por anúncio assistido.
INSERT INTO "ad_rewards" ("id", "kind", "title", "description", "amount", "dailyLimit", "cooldownSecs", "active", "sortOrder", "updatedAt") VALUES
    ('6f1d1a52-0c1b-4f7e-9a53-1c2b7d0a0004', 'VIP', 'VIP por 1 hora', 'Veja quem te curtiu e use os filtros VIP e o modo incógnito.', 1, 3, 0, true, 0, CURRENT_TIMESTAMP)
ON CONFLICT ("id") DO NOTHING;
