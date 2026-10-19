-- Blocos do Google Ad Manager para Android (rede 23340104016, pasta mypair.app).
-- Só preenche campos vazios ou com ID no formato antigo do AdMob
-- (ca-app-pub-.../...), que não funciona com as classes do Ad Manager usadas
-- pelo app. Blocos já no formato do Ad Manager ficam como estão. O Modo teste
-- e os formatos ligados/desligados não mudam (continuam no painel, em Anúncios).

INSERT INTO "ad_settings" ("id", "updatedAt") VALUES (1, CURRENT_TIMESTAMP)
ON CONFLICT ("id") DO NOTHING;

UPDATE "ad_settings" SET
    "androidAppOpenId" = CASE
        WHEN COALESCE(BTRIM("androidAppOpenId"), '') = '' OR "androidAppOpenId" LIKE 'ca-app-pub-%'
        THEN '/23340104016/mypair.app/namoro-android-app-open' ELSE "androidAppOpenId" END,
    "androidBannerId" = CASE
        WHEN COALESCE(BTRIM("androidBannerId"), '') = '' OR "androidBannerId" LIKE 'ca-app-pub-%'
        THEN '/23340104016/mypair.app/namoro-android-banner' ELSE "androidBannerId" END,
    "androidInterstitialId" = CASE
        WHEN COALESCE(BTRIM("androidInterstitialId"), '') = '' OR "androidInterstitialId" LIKE 'ca-app-pub-%'
        THEN '/23340104016/mypair.app/namoro-android-interstitial' ELSE "androidInterstitialId" END,
    "androidRewardedInterstitialId" = CASE
        WHEN COALESCE(BTRIM("androidRewardedInterstitialId"), '') = '' OR "androidRewardedInterstitialId" LIKE 'ca-app-pub-%'
        THEN '/23340104016/mypair.app/namoro-android-rewarded-interstitial' ELSE "androidRewardedInterstitialId" END,
    "androidNativeId" = CASE
        WHEN COALESCE(BTRIM("androidNativeId"), '') = '' OR "androidNativeId" LIKE 'ca-app-pub-%'
        THEN '/23340104016/mypair.app/namoro-android-native' ELSE "androidNativeId" END,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" = 1;

-- Premiado: com a confirmação do Google (SSV) exigida o bloco fica travado.
-- Ao trocar o bloco, a prova do SSV do bloco antigo deixa de valer.
UPDATE "ad_settings" SET
    "androidRewardedId" = '/23340104016/mypair.app/namoro-android-rewarded',
    "rewardsSsvAdUnit" = NULL,
    "rewardsSsvLastAt" = NULL,
    "rewardsSsvLastAdUnit" = NULL,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" = 1
  AND "rewardsRequireSsv" = false
  AND (COALESCE(BTRIM("androidRewardedId"), '') = '' OR "androidRewardedId" LIKE 'ca-app-pub-%');
