مشروع متجر شنط 

هقسمه 6 أجزاء:
1️⃣ User Flow
2️⃣ Pages & Features (User)
3️⃣ Cart & Order Logic
4️⃣ Payment Flow
5️⃣ Admin Flow
6️⃣ Data & Status Logic (مهم جدًا)

---

## 1️⃣ User Flow (رحلة المستخدم كاملة)

### 1. دخول المستخدم

* Login

  * Username + Password
  * Login with Google
* Sign Up

  * username
  * full name
  * phone
  * email
  * government

🔒 لا يقدر يعمل:

* add to cart
* checkout
  إلا وهو **Logged in**

---

### 2. Home Page

يعرض:

* About Us
* Sample of **Sale Items**
* Sample of **Latest Items (Bags)**
* زر:

  * View All Sale
  * View All Bags

---

### 3. Browse Products

المستخدم يقدر:

* يدخل صفحة **Sale**
* يدخل صفحة **Bags (All items)**

كل Product Card فيها:

* Image
* Name
* Price
* Sale Price (لو موجود)
* Available / Out of Stock

---

### 4. Product Details Page

فيها:

* اسم المنتج
* وصف
* السعر (أو سعر السيل)
* الألوان المتاحة
* الكمية المتاحة (ككل – مش لكل لون)

المنطق:

* المستخدم يختار:

  * Color
  * Quantity
* ❌ ممنوع يختار Quantity > Stock
* لو stock = 0 → المنتج **غير متاح**

زر:

* Add to Cart

---

## 2️⃣ Cart Flow

### Cart Page

تعرض:

* List المنتجات المختارة
* لكل منتج:

  * الاسم
  * اللون
  * السعر
  * الكمية

المستخدم يقدر:

* ➕ يزيد الكمية (لحد stock)
* ➖ يقلل الكمية
* ❌ يشيل المنتج
* ✔️ Proceed to Checkout

🧠 **الـ Stock بيتحجز مؤقتًا** وقت الإضافة للعربة

---

## 3️⃣ Order Flow (Confirm Order)

### Checkout Page

Form فيه:

* Name
* Phone
* Another Phone
* Email
* Detailed Address

بعدها:

* Order Summary
* Total Price

اختيار الدفع:

* 💵 Cash on Delivery
* 💳 Online Payment

زر:

* Confirm Order

---

## 4️⃣ Payment Flow

### A) Cash on Delivery

* Order يتعمل
* Status = **New**
* Payment Status = **Cash Pending**

---

### B) Online Payment

* Redirect to Payment Gateway
* بعد الدفع:

  * Payment Success → Order Created
  * Payment Failed → Order Cancelled

Status:

* Order Status = **New**
* Payment Status = **Paid**

---

## 5️⃣ Order Status Logic (مهم جدًا)

### Order Status

* New (أول ما العميل يعمل أوردر)
* Shipped
* Cancelled

### Rules:

* New → Shipped (بواسطة Admin)
* New → Cancelled (Admin أو User)
* Shipped → ❌ لا يتعدل إلا:

  * Shipped → Cancelled (مع خصم الفلوس)

---

### Stock Logic

* عند إنشاء الأوردر:

  * الكمية تتخصم من Stock
* عند Cancel:

  * الكمية ترجع للـ Stock

---

## 6️⃣ Admin Flow 👑

### Admin Dashboard

---

### 1. Orders Page

يعرض:

* All Orders
* Filters:

  * New
  * Shipped
  * Cancelled

لكل Order:

* Order Details
* User Info
* Payment Type
* Total Price

Admin Actions:

* Change Status (New → Shipped)
* Cancel Order
* Add Notes (Internal)

📢 لما الحالة تتغير:

* المستخدم يشوف التحديث عنده

---

### 2. Items Page

Admin يقدر:

* Add New Item
* Edit Item
* Delete Item

Item Details:

* Name
* Description
* Price
* Colors:

  * لكل لون:

    * Quantity

🧠 **المستخدم يشوف Total Stock فقط**
لو مجموع الكميات = 0 → المنتج غير متاح

---

### 3. Sale Page

Admin:

* يختار منتج **من Items فقط**
* يحدد:

  * Sale Percentage أو Sale Price

❌ ممنوع يعمل Sale لمنتج مش موجود

---

### 4. Transactions Page (Financial Logic)

تعرض:

* كل عمليات الدفع
* لكل Order:

  * Payment Method
  * Amount
  * Status

🧮 الحسابات:

* Online Paid + Shipped → +Balance
* Cash + Shipped → +Balance
* Shipped → Cancelled → −Balance

---

## 7️⃣ Contact Us Page

* QR Code → WhatsApp Chat
* Contact Form:

  * Name
  * Email
  * Message

---

## 🔥 Summary (Flow مختصر)

1. User Login / Signup
2. Browse Home → Sale → Bags
3. Product → Add to Cart
4. Cart → Checkout
5. Cash أو Online Payment
6. Order = New
7. Admin:

   * Shipped
   * Cancel
8. Stock & Transactions تتحدث تلقائيًا

---


