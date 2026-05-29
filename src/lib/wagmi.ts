import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { arcTestnet } from "./chains";

const projectId =
  process.env.NEXT_PUBLIC_WC_PROJECT_ID ?? "trailhead-dev-placeholder";

export const wagmiConfig = getDefaultConfig({
  appName: "Trailhead",
  projectId,
  chains: [arcTestnet],
  ssr: true,
});
