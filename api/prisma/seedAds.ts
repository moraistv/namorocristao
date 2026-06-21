import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

// IDs de TESTE oficiais do Google (Android).
const TEST = {
  appOpen: "ca-app-pub-3940256099942544/9257395921",
  banner: "ca-app-pub-3940256099942544/6300978111",
  interstitial: "ca-app-pub-3940256099942544/1033173712",
  rewarded: "ca-app-pub-3940256099942544/5224354917",
  rewardedInterstitial: "ca-app-pub-3940256099942544/5354046379",
  native: "ca-app-pub-3940256099942544/2247696110",
};

async function main() {
  const data = {
    enabled: true,
    testMode: true,
    appOpenEnabled: true,
    bannerEnabled: true,
    interstitialEnabled: true,
    rewardedEnabled: true,
    rewardedInterstitialEnabled: false,
    nativeEnabled: false,
    androidAppOpenId: TEST.appOpen,
    androidBannerId: TEST.banner,
    androidInterstitialId: TEST.interstitial,
    androidRewardedId: TEST.rewarded,
    androidRewardedInterstitialId: TEST.rewardedInterstitial,
    androidNativeId: TEST.native,
    bannerPosition: "bottom",
    appOpenOnResume: true,
    appOpenEverySecs: 0,
    interstitialEverySecs: 60,
    interstitialEveryClicks: 0,
    interstitialOnOpenChat: true,
    interstitialOnOpenProfile: false,
    interstitialOnSwipe: false,
    maxAdsPerSession: 0,
    maxAdsPerDay: 0,
  };
  await prisma.adSettings.upsert({
    where: { id: 1 },
    create: { id: 1, ...data },
    update: data,
  });
  console.log("✅ AdSettings preenchido com IDs de TESTE do Google.");
}

main().finally(() => prisma.$disconnect());
