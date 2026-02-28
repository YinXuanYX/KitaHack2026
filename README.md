<div align="center">

# 🌍 Wastave 🍽️

**Empowering Local Commerce & Combating Food Waste, Together.**

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)](https://firebase.google.com/)
[![Google Gemini](https://img.shields.io/badge/Google%20Gemini-%238E75B2.svg?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)

*Built for KitaHack 2026*

<br>
</div>

## ✨ What is Wastave?

Wastave is a beautifully crafted, dual-purpose community marketplace designed to seamlessly connect local consumers with neighborhood vendors. More than just a directory, Wastave acts as an intelligent local commerce and sustainability platform where users can rescue surplus food, verify pickups instantly, and get smart recommendations from an AI-powered assistant.

Whether you're a small business looking to move inventory rapidly, or a sustainability-minded local looking for great deals, Wastave is your home.

---

## 🚀 Key Features

### 👥 Dual-Role Architecture
A single application catering to two distinct user journeys:
*   **For Vendors:** A dedicated dashboard to manage inventory via quick-add camera listing, track sales, and fulfill upcoming orders.
*   **For Consumers:** A vibrant storefront interface embedded with Google Maps integration to find the best local deals right around the corner.

### 🤖 Smart "Green" AI Assistant 
Powered by **Google Gemini** (`google_generative_ai`), our built-in chatbot acts as a smart community manager. Users can ask questions about sustainable eating, optimal food storage, and even app navigation—reducing repetitive inquiries for vendors and vastly enriching the consumer experience.

### ⚡ Real-Time P2P Chat
Integrated Firebase Firestore enables instantaneous, peer-to-peer messaging between vendors and consumers to coordinate pickup times, confirm item availability, and build community trust.

### 📱 Instant QR Verification
No more confusing pickup lines. A secure, built-in QR generation and scanning workflow guarantees seamless order fulfillment using the device's camera.

---

## 🛠️ Tech Stack

*   **Frontend Magic:** Flutter & Dart
*   **Backend engine:** Firebase (Auth, Cloud Firestore, Cloud Storage)
*   **Location Services:** Google Maps for Flutter, Geolocator, Google Places API
*   **Media & Hardware:** `image_picker`, `mobile_scanner`, `qr_flutter`
*   **AI Integration:** `google_generative_ai`

---

## 💻 Getting Started

### Prerequisites
*   Flutter SDK (^3.9.0 or higher)
*   Dart SDK
*   Firebase project configured (with a properly generated `firebase_options.dart` file inside `lib/`)

### Installation & Run Instructions

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/YourUsername/KitaHack2026.git
    cd KitaHack2026
    ```

2.  **Fetch Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run the App**
    Connect a physical device or power up an emulator/simulator:
    ```bash
    flutter run
    ```

> *Note: For full functionality including Maps and AI, ensure your Google Maps API Keys and Google Generative AI API Keys are properly set within their respective configuration files or environment variables.*

---

## 🌟 Hackathon Impact Focus

We built Wastave not only to be technically robust but to deliver tangible real-world value:
*   **Iteration & Feedback:** Rapidly validated through direct interviews with small business owners and locals, leading to UI/UX pivots like replacing heavy text-entry fields with lightning-fast image uploads.
*   **Real-time Synchronization:** Prioritized aggressive App state optimization using `provider` and targeted `StreamBuilders` combined with Firestore's offline capabilities.
*   **Infinitely Scalable:** Wastave's serverless Firebase backbone means handling traffic spikes—from one local market block to an entire city grid—requires virtually zero architectural overhaul.

<br>
<div align="center">
  <i>Made with ❤️ by the KitaHack 2026 Team</i>
</div>