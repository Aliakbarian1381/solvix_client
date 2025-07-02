importScripts("https://www.gstatic.com/firebasejs/9.2.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.2.0/firebase-messaging-compat.js");

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config object.
// این مقادیر را از کنسول فایربیس (بخش Project settings -> General) کپی کنید
const firebaseConfig = {
    apiKey: "AIzaSyAUr6bFkj_249JlKPxcht1njYEtchwWLws",
           authDomain: "solvix-f2e4c.firebaseapp.com",
           projectId: "solvix-f2e4c",
           storageBucket: "solvix-f2e4c.firebasestorage.app",
           messagingSenderId: "177581789113",
           appId: "1:177581789113:web:775695a0d2056333c3b068",
           measurementId: "G-KZESBQ0DC9",
};

firebase.initializeApp(firebaseConfig);

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png' // می‌توانید آیکون خود را قرار دهید
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});