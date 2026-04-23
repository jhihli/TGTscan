## NextAuth Login Trigger Flow

1. When a user submits the login form, the request is sent to the built-in NextAuth sign-in endpoint: POST /api/auth/callback/credentials

2. Next, NextAuth handles the request using the authorize function inside CredentialsProvider.

3. If authentication is successful, NextAuth moves to the JWT callback: "async jwt({ token, user })",
jwt callback is triggered only when a new user logs in.
The user object from authorize() is passed to jwt(), and stored inside token.

4. Once the JWT is generated, NextAuth calls the session callback: "async session({ session, token })""
This is triggered every time the session is accessed.
Now, session.user.role is available to the frontend.


5. After the session callback, NextAuth sets the session cookie in the browser.
The browser now has a cookie named next-auth.session, which keeps the user logged in.




## Why need next-auth.d.ts

Because the default session.user of NextAuth didn't inclue role, need to let TypeScript know the new field role.



## middleware.ts use for 

withAuth runs before every request to check authentication of user.



