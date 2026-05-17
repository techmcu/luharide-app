importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDummy",
  projectId: "luharide-app",
  messagingSenderId: "698013485373",
  appId: "1:698013485373:web:0000000000000000",
});

const messaging = firebase.messaging();
