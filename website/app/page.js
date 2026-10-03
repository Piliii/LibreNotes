import Navbar from "@/components/Navbar";
import HeroSection from "@/components/HeroSection";
import ScreenshotsSection from "@/components/ScreenshotsSection";
import FeaturesSection from "@/components/FeaturesSection";
import WhatsNewSection from "@/components/changelog/WhatsNewSection";
import WhatsNewModal from "@/components/changelog/WhatsNewModal";
import DemoSection from "@/components/DemoSection";
import DownloadSection from "@/components/DownloadSection";
import ServerSetupSection from "@/components/ServerSetupSection";
import SectionDivider from "@/components/SectionDivider";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <>
      <Navbar />
      <main id="main">
        <HeroSection />
        <SectionDivider />
        <ScreenshotsSection />
        <SectionDivider />
        <FeaturesSection />
        <SectionDivider />
        <DemoSection />
        <SectionDivider />
        <DownloadSection />
        <SectionDivider />
        <ServerSetupSection />
        <SectionDivider />
        <WhatsNewSection />
      </main>
      <Footer />
      <WhatsNewModal />
    </>
  );
}
