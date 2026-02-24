# What2Eat

A collaborative web platform for users to decide what to eat with friends and family.

Sofware Requirements Specifications (SRS): https://docs.google.com/document/d/19WuPz1RHFcWTKamXx_DDYhd5wL3Z1d1AvZ3Xeb-I4Dg/edit?usp=sharing 

GitHub link: https://github.com/mrchuakaiming/KitaHack-2026

# Introduction
Deciding where and what to eat in a group with **friends, family, or coworkers** in **everyday social settings** is often stressful, time-consuming, and inefficient. In our survey, 64% of participants reported difficulty deciding what to eat in a group, and 45% spent more than 10 minutes choosing a restaurant. Conflicting tastes, dietary restrictions (e.g., vegetarian, gluten-free, halal), budget limits, and social pressures make consensus difficult. Traditional tools like messaging apps, reviews, or social media fail to account for these factors, and dominant voices often steer decisions while quieter participants remain silent, resulting in dissatisfaction.

What2Eat addresses this by providing a collaborative web platform where users can safely share preferences and constraints. AI-powered reasoning (Google Gemini) generates food suggestions that satisfy everyone, mitigating social bias and dominance. **This matters** because it allows groups to reach fair, inclusive, and efficient dining decisions, reducing debate, social friction, and decision time, and making everyday group dining more enjoyable and equitable.

## How to run
To run and deploy this project using Firebase, first ensure that Node.js (v16 or above), npm, and a Firebase account are installed, then install the Firebase CLI globally using `npm install -g firebase-tools` and log in with `firebase login`. Clone the repository and navigate into the project folder, then install dependencies using `npm install` (and if Cloud Functions are included, run `npm install` inside the `functions` folder as well). If Firebase has not been initialized, run `firebase init` and select the required services (e.g., Hosting, Firestore, Functions), linking to the existing Firebase project and specifying the correct hosting directory (such as `public` or `dist`). To test locally, you may use `firebase emulators:start` or the framework’s development command (e.g., `npm run dev`). Finally, deploy the project using `firebase deploy`, or deploy specific services with `firebase deploy --only hosting` or `firebase deploy --only functions`; once completed, Firebase will provide a hosting URL where the live application can be accessed.

For more information on how to run the Firebase hosted application, please visit https://firebase.google.com/

To use the deployed application: https://what2eat-1469f.web.app

# Technical Architecture
The system follows a deployment architecture (web-based, server hosted) consisting of:

**Frontend (Flutter Web)**<br>
Handles user interaction, including registration, room management, preference submission, and result display. The MVVM pattern separates UI from business logic to improve maintainability.

**Backend (Firebase Cloud Functions in Python)**<br>
Processes business logic, aggregates user data, integrates with external services (Gemini and Google Maps APIs), and enforces system rules securely on the server side. All external API calls are executed exclusively within this layer to ensure controlled access and data security.

**Database Layer (Firestore + Realtime Database)**<br>
Firestore stores persistent structured data such as user profiles and room metadata, while Realtime Database handles live room state for real-time submission tracking.

To read all about the system architecture for this project, please see our software requirements specification, section 6.0 System Architecture: https://docs.google.com/document/d/19WuPz1RHFcWTKamXx_DDYhd5wL3Z1d1AvZ3Xeb-I4Dg/edit?usp=sharing 

# Implementation details
**Frontend Implementation**<br>

The frontend is developed using Flutter with Dart and follows a reactive, widget-based structure. State management is implemented using the Provider package to ensure clean separation between UI and application logic. This design supports maintainability and efficient updates to the user interface.

**Backend Implementation**<br>

Cloud Functions written in Python are used to implement server-side logic, including preference aggregation, validation of inputs, and interaction with external APIs. Python was selected due to its strong support for HTTP requests, JSON processing, and integration with third-party services.

**AI Integration Process**<br>

The recommendation process begins with the server aggregating structured user preference data, such as cuisine selections, dietary restrictions, and budget ranges. This data is formatted into a controlled JSON structure and sent to the Google Gemini API through a secure server-side request. The AI response is validated, parsed, and processed before being returned to the client to ensure correctness and consistency.

**Database Configuration**<br>

Firestore is configured with structured document models and indexed queries to support efficient retrieval of room and user data. Realtime Database is implemented for low-latency updates, such as tracking participant submissions and live room status. This design aligns each database with its intended use case.

**Security and Testing**<br>

Firebase Authentication is integrated with security rules to ensure that only authorized users can access or modify data. Sensitive information, such as API keys, is stored and managed within Cloud Functions. Testing tools, including Mocktail, are used to verify application logic and ensure system reliability.

To see all the technologies used in this project, please see our software requirements specification: https://docs.google.com/document/d/19WuPz1RHFcWTKamXx_DDYhd5wL3Z1d1AvZ3Xeb-I4Dg/edit?usp=sharing 

# Challenges Faced
## Context
A major technical challenge was the original database design, which used only two Firestore collections to manage both persistent user data and volatile room state. 

## Problem
Although this structure initially appeared sufficient, it became difficult to support real-time tracking of participant submissions. The deeply nested Firestore documents limited clarity and did not efficiently support low-latency synchronization for live updates. Without a dedicated real-time data layer, the architecture would have become increasingly complex, harder to maintain, and less scalable as concurrent users increased.

## Analysis
After analysing the system requirements, we identified that high-frequency room state updates were better suited to Firebase Realtime Database. In addition, further normalisation of our setup could make the database solution easier to comprehend and more maintainable.

## Solution and Results
We refactored the persistence layer into a hybrid architecture, separating structured long-term data in Firestore from real-time session data in Realtime Database. This improved maintainability, clarity, and live responsiveness. 

## Trade-off
The main trade-off with our decision in face of the technical challenge was increased architectural complexity. Using both Firestore and Realtime Database required additional integration logic and careful coordination between data sources. However, this compromise was necessary to achieve real-time collaboration while preserving structured and scalable data storage. The improved separation of concerns outweighed the added implementation complexity.

## Reflection
In the end, we learned that database design must be structured according to access patterns and real-time requirements, rather than based solely on familiarity or convenience.

To see elaborated challenges faced in this project, please see our software requirements specification, section 12.0 Challenges Faced: https://docs.google.com/document/d/19WuPz1RHFcWTKamXx_DDYhd5wL3Z1d1AvZ3Xeb-I4Dg/edit?usp=sharing

# Future roadmap
Over the next 2–3 years, the system can expand beyond its initial target user base to reach wider communities, including working professionals, families, and corporate teams who frequently make group dining decisions. With growth in both B2C subscriptions and B2B partnerships, the platform can strengthen its monetisation strategy through membership plans, premium features, and potential data licensing opportunities.

Future development opportunities include improving recommendation personalisation, integrating advanced location-based filtering, and expanding collaborative features such as controlled response editing and enhanced analytics. These enhancements can increase user retention, improve satisfaction, and strengthen the platform’s competitive advantage, enabling it to evolve into a widely adopted collaborative dining solution, and enable sustainable revenue expansion across additional cities and eventually international markets.

To see expanded future plans for this project, please see our software requirements specification, section 10.4 Future Development Roadmap: https://docs.google.com/document/d/19WuPz1RHFcWTKamXx_DDYhd5wL3Z1d1AvZ3Xeb-I4Dg/edit?usp=sharing

# Closing
In conclusion, What2Eat is a collaborative web-based platform designed to simplify and improve group dining decisions through structured preference collection and AI-powered recommendations. By combining Flutter for the frontend, Firebase for backend services, and Google Gemini for intelligent reasoning, the system provides a secure, scalable, and real-time solution to the common problem of group meal selection. The project demonstrates effective integration of modern web technologies, cloud services, and artificial intelligence to enhance fairness, efficiency, and user satisfaction in everyday social decision-making. Moving forward, the platform has strong potential for further development, broader adoption, and continuous improvement.