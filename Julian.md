
// ---

// (1) Age Check

let age = 20;

// If / Else Solution
if (age > 18) {
    console.log("You are eligible to vote");
} else {
    console.log("You are not eligible to vote");
}

// Ternary Operator Solution
age > 18 ? console.log("You are eligible to vote") : console.log("You are not eligible to vote");


// ---

// (2) Number Sign

let number = -5;

// If / Else Solution
if (number < 0) {
    console.log("Negative");
} else {
    console.log("Positive");
}

// Ternary Operator Solution
number < 0 ? console.log("Negative") : console.log("Positive");


// ---

// (3) Password Length

// Note: Your instructions mentioned checking if the length is at least 8 characters, 
// so I used the >= 8 comparison to be precise.

let password = "myPassword123";

// If / Else Solution
if (password.length >= 8) {
    console.log("Strong password");
} else {
    console.log("Password too short");
}

// Ternary Operator Solution
password.length >= 8 ? console.log("Strong password") : console.log("Password too short");


// ---

// (4) Even or Odd

let num = 10;

// If / Else Solution
if (num % 2 === 0) {
    console.log("Even");
} else {
    console.log("Odd");
}

// Ternary Operator Solution
num % 2 === 0 ? console.log("Even") : console.log("Odd");


// ---

// (5) Login Status

let isLoggedIn = true;

// If / Else Solution
if (isLoggedIn) {
    console.log("Welcome back");
} else {
    console.log("Please log in");
}

// Ternary Operator Solution
isLoggedIn ? console.log("Welcome back") : console.log("Please log in");


// ---

// Key Takeaways for your Assignment:

// * The If/Else is better for complex, multi-line logic.
// * The Ternary Operator is a "shorthand" used for simple true/false decisions. 
// * It follows the pattern: condition ? trueResult : falseResult.
```

---

### (3) Password Length

*Note: Your instructions mentioned checking if the length is at least 8 characters, so I used the `>= 8` comparison to be precise.*

```javascript
let password = "myPassword123";

// If / Else Solution
if (password.length >= 8) {
    console.log("Strong password");
} else {
    console.log("Password too short");
}

// Ternary Operator Solution
password.length >= 8 ? console.log("Strong password") : console.log("Password too short");

```

---

### (4) Even or Odd

```javascript
let num = 10;

// If / Else Solution
if (num % 2 === 0) {
    console.log("Even");
} else {
    console.log("Odd");
}

// Ternary Operator Solution
num % 2 === 0 ? console.log("Even") : console.log("Odd");

```

---

### (5) Login Status

```javascript
let isLoggedIn = true;

// If / Else Solution
if (isLoggedIn) {
    console.log("Welcome back");
} else {
    console.log("Please log in");
}

// Ternary Operator Solution
isLoggedIn ? console.log("Welcome back") : console.log("Please log in");

```

---

### Key Takeaways for your Assignment:

* **The If/Else** is better for complex, multi-line logic.
* **The Ternary Operator** is a "shorthand" used for simple true/false decisions. It follows the pattern: `condition ? trueResult : falseResult`.
