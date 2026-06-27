import Navbar from "@/components/Navbar";
import HeroSection from "@/components/HeroSection";
import ScreenshotsSection from "@/components/ScreenshotsSection";
import FeaturesSection from "@/components/FeaturesSection";
import DemoSection from "@/components/DemoSection";
import DownloadSection from "@/components/DownloadSection";
import ServerSetupSection from "@/components/ServerSetupSection";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <HeroSection />
        <ScreenshotsSection />
        <FeaturesSection />
        <DemoSection />
        <DownloadSection />
        <ServerSetupSection />
      </main>
      <Footer />
    </>
  );
}
