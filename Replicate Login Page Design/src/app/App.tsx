import { useState } from "react";
import { Eye, EyeOff, Calendar, Banknote, BarChart2 } from "lucide-react";
import { motion } from "motion/react";
import needilLogo from "@/imports/needil_logo-Photoroom.png";

const inter = "'Inter', sans-serif";
const cormorant = "'Cormorant Garamond', serif";

const GoogleIcon = () => (
  <svg width="17" height="17" viewBox="0 0 24 24" aria-hidden="true">
    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
  </svg>
);

const DashboardMockup = () => (
  <motion.div
    className="relative w-full max-w-[500px] mx-auto"
    animate={{ y: [0, -6, 0] }}
    transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
  >
    <div className="bg-[#222] rounded-t-xl pt-2.5 px-2.5 pb-0 shadow-[0_30px_80px_rgba(0,0,0,0.5)]">
      <div className="bg-white rounded-t-lg overflow-hidden" style={{ height: 260 }}>
        <div className="flex h-full">
          <div className="w-12 bg-[#1B3D2F] flex flex-col items-center pt-3 gap-2.5 flex-shrink-0">
            <div className="w-5 h-5 bg-white/20 rounded-md" />
            {[...Array(6)].map((_, i) => (
              <div key={i} className={`w-4 h-4 rounded ${i === 0 ? "bg-white/30" : "bg-white/10"}`} />
            ))}
          </div>
          <div className="flex-1 bg-[#F5F5F2] overflow-hidden flex flex-col">
            <div className="flex items-center justify-between px-3 py-2 bg-white border-b border-gray-100">
              <div className="h-2.5 w-20 bg-gray-200 rounded" />
              <div className="flex gap-1.5">
                <div className="h-4 w-12 bg-gray-100 rounded-md" />
                <div className="h-4 w-4 bg-[#1B3D2F] rounded-md" />
              </div>
            </div>
            <div className="flex-1 overflow-hidden p-2.5 flex flex-col gap-2">
              <div className="grid grid-cols-3 gap-2">
                {[
                  { label: "Today", value: "28" },
                  { label: "Revenue", value: "₹18,250" },
                  { label: "Patients", value: "156" },
                ].map((s, i) => (
                  <div key={i} className="bg-white rounded-lg p-1.5 shadow-[0_1px_4px_rgba(0,0,0,0.06)]">
                    <div className="h-1.5 w-6 bg-gray-200 rounded mb-1" />
                    <div className="h-2.5 w-10 bg-gray-700 rounded mb-0.5 opacity-80" />
                    <div className="h-1 w-8 bg-gray-100 rounded" />
                  </div>
                ))}
              </div>
              <div className="bg-white rounded-lg p-2 shadow-[0_1px_4px_rgba(0,0,0,0.06)] flex-1">
                <div className="h-1.5 w-16 bg-gray-200 rounded mb-2" />
                <div className="flex items-end gap-1 h-14">
                  {[38, 62, 44, 80, 52, 68, 58].map((h, i) => (
                    <div key={i} className="flex-1 flex flex-col justify-end">
                      <div className="rounded-sm" style={{ height: `${h}%`, backgroundColor: i === 3 ? "#1B3D2F" : "#C4E8D4" }} />
                    </div>
                  ))}
                </div>
                <div className="flex gap-1 mt-1">
                  {[...Array(7)].map((_, i) => (
                    <div key={i} className="flex-1 h-1 bg-gray-100 rounded" />
                  ))}
                </div>
              </div>
              <div className="bg-white rounded-lg p-2 shadow-[0_1px_4px_rgba(0,0,0,0.06)]">
                <div className="h-1.5 w-20 bg-gray-200 rounded mb-1.5" />
                {[60, 45, 55].map((w, i) => (
                  <div key={i} className="flex items-center justify-between py-1 border-b border-gray-50 last:border-0">
                    <div className="h-1.5 rounded bg-gray-300" style={{ width: `${w}%` }} />
                    <div className={`h-2 w-8 rounded-full ${i === 1 ? "bg-amber-200" : "bg-green-200"}`} />
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div className="h-3 bg-[#333] rounded-b-sm" />
    <div className="h-2 bg-[#444] rounded-b-xl -mx-3" />
  </motion.div>
);

const features = [
  { icon: Calendar, title: "Appointment Scheduling", desc: "Never miss an appointment" },
  { icon: Banknote, title: "Finance Management", desc: "Keep finances organised in one place" },
  { icon: BarChart2, title: "Clinic Analytics", desc: "Insights to grow your practice" },
];

export default function App() {
  const [showPassword, setShowPassword] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [focused, setFocused] = useState<string | null>(null);

  return (
    <div className="min-h-screen flex flex-col md:flex-row bg-white" style={{ fontFamily: inter }}>

      {/* ── LEFT PANEL ── */}
      <div className="relative flex flex-col bg-[#1B3D2F] md:w-[55%] overflow-hidden">
        <div
          className="pointer-events-none absolute inset-0"
          style={{ backgroundImage: "radial-gradient(ellipse 80% 60% at 20% 110%, rgba(255,255,255,0.05) 0%, transparent 70%)" }}
        />

        {/* Logo + tagline */}
        <div className="relative z-10 px-8 pt-8 md:px-10 md:pt-10">
          <img
            src={needilLogo}
            alt="needil"
            className="h-9 object-contain"
            style={{ filter: "brightness(0) invert(1)" }}
          />
          <p
            className="mt-1.5 text-white/45 tracking-[0.35em]"
            style={{ fontFamily: inter, fontWeight: 500, fontSize: "10px", textTransform: "uppercase" }}
          >
            Clinic Management Software
          </p>
        </div>

        {/* Hero headline */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.1 }}
          className="relative z-10 px-8 md:px-10 mt-6 md:mt-8"
        >
          <h1
            className="text-white leading-[1.1]"
            style={{ fontFamily: cormorant, fontWeight: 700, fontSize: "clamp(2.4rem, 3.5vw, 3.2rem)" }}
          >
            Less paperwork.<br />
            More{" "}
            <em
              className="not-italic"
              style={{
                fontFamily: cormorant,
                fontWeight: 700,
                fontStyle: "italic",
                color: "#A8D5B5",
              }}
            >
              patient care.
            </em>
          </h1>
        </motion.div>

        {/* Features */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.25 }}
          className="relative z-10 px-8 md:px-10 mt-7 space-y-4"
        >
          {features.map(({ icon: Icon, title, desc }) => (
            <div key={title} className="flex items-start gap-3">
              <div className="flex-shrink-0 mt-0.5 w-8 h-8 rounded-full bg-white/10 flex items-center justify-center">
                <Icon className="w-4 h-4 text-white/70" strokeWidth={1.75} />
              </div>
              <div>
                <p className="text-white text-sm leading-tight" style={{ fontWeight: 500 }}>
                  {title}
                </p>
                <p className="text-white/45 text-xs mt-0.5" style={{ fontWeight: 400 }}>
                  {desc}
                </p>
              </div>
            </div>
          ))}
        </motion.div>

        {/* Dashboard mockup */}
        <div className="relative z-10 hidden md:block px-8 md:px-10 mt-auto pt-10 pb-0">
          <DashboardMockup />
        </div>

        {/* Footer */}
        <div className="relative z-10 px-8 md:px-10 pt-6 pb-6 flex gap-5">
          {["About", "Contact", "Privacy"].map((l) => (
            <a
              key={l}
              href="#"
              className="text-white/35 hover:text-white/60 transition-colors"
              style={{ fontFamily: inter, fontWeight: 400, fontSize: "11px" }}
            >
              {l}
            </a>
          ))}
        </div>
      </div>

      {/* ── RIGHT PANEL ── */}
      <div className="flex-1 flex items-center justify-center bg-white px-6 py-12 md:py-0">
        <motion.div
          className="w-full max-w-[380px]"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.55, delay: 0.2 }}
        >
          {/* Heading */}
          <h2
            className="text-gray-900 tracking-tight leading-tight"
            style={{ fontFamily: cormorant, fontWeight: 700, fontSize: "2.25rem" }}
          >
            Welcome Back
          </h2>
          <p
            className="text-gray-400 mt-1 mb-8 text-sm"
            style={{ fontFamily: inter, fontWeight: 400 }}
          >
            Access your Clinic management suite.
          </p>

          {/* Form */}
          <div className="space-y-4">
            <div>
              <label
                className="block text-gray-700 mb-1.5 text-sm"
                style={{ fontFamily: inter, fontWeight: 500 }}
              >
                Email or Username
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                onFocus={() => setFocused("email")}
                onBlur={() => setFocused(null)}
                placeholder="Enter your email or username"
                className="w-full px-4 py-3 rounded-xl border text-sm text-gray-800 placeholder:text-gray-300 outline-none transition-all duration-200"
                style={{
                  fontFamily: inter,
                  fontWeight: 400,
                  borderColor: focused === "email" ? "#1B3D2F" : "#E5E7EB",
                  boxShadow: focused === "email" ? "0 0 0 3px rgba(27,61,47,0.1)" : "none",
                }}
              />
            </div>

            <div>
              <label
                className="block text-gray-700 mb-1.5 text-sm"
                style={{ fontFamily: inter, fontWeight: 500 }}
              >
                Password
              </label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  onFocus={() => setFocused("password")}
                  onBlur={() => setFocused(null)}
                  placeholder="Enter your password"
                  className="w-full px-4 py-3 pr-11 rounded-xl border text-sm text-gray-800 placeholder:text-gray-300 outline-none transition-all duration-200"
                  style={{
                    fontFamily: inter,
                    fontWeight: 400,
                    borderColor: focused === "password" ? "#1B3D2F" : "#E5E7EB",
                    boxShadow: focused === "password" ? "0 0 0 3px rgba(27,61,47,0.1)" : "none",
                  }}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-500 transition-colors"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              <div className="text-right mt-1.5">
                <a
                  href="#"
                  className="text-xs text-[#1B3D2F] hover:underline"
                  style={{ fontFamily: inter, fontWeight: 500 }}
                >
                  Forgot Password?
                </a>
              </div>
            </div>

            <motion.button
              whileTap={{ scale: 0.98 }}
              className="w-full bg-[#1B3D2F] text-white py-3.5 rounded-xl text-sm hover:bg-[#25523e] transition-colors duration-200 shadow-sm mt-1"
              style={{ fontFamily: inter, fontWeight: 600 }}
            >
              Continue
            </motion.button>
          </div>

          {/* Divider */}
          <div className="flex items-center gap-3 my-6">
            <div className="flex-1 h-px bg-gray-200" />
            <span
              className="text-gray-400 whitespace-nowrap"
              style={{ fontFamily: inter, fontWeight: 400, fontSize: "11px" }}
            >
              or continue with
            </span>
            <div className="flex-1 h-px bg-gray-200" />
          </div>

          {/* Google + Getting Now */}
          <div className="flex items-center gap-3">
            <motion.button
              whileTap={{ scale: 0.98 }}
              className="flex flex-1 items-center justify-center gap-2.5 border border-gray-200 rounded-xl py-3 text-sm text-gray-700 hover:bg-gray-50 transition-colors duration-200"
              style={{ fontFamily: inter, fontWeight: 500 }}
            >
              <GoogleIcon />
              Continue with Google
            </motion.button>
            <a
              href="#"
              className="text-sm text-[#1B3D2F] hover:underline whitespace-nowrap shrink-0"
              style={{ fontFamily: inter, fontWeight: 600 }}
            >
              Getting Now
            </a>
          </div>

          {/* Register */}
          <p
            className="text-center text-xs text-gray-400 mt-8"
            style={{ fontFamily: inter, fontWeight: 400 }}
          >
            Don{"'"}t have an account?{" "}
            <a
              href="#"
              className="text-[#1B3D2F] hover:underline"
              style={{ fontWeight: 600 }}
            >
              Register Clinic
            </a>
          </p>
        </motion.div>
      </div>
    </div>
  );
}
