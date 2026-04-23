"use client"
import { lusitana } from '@/app/ui/fonts';
import {
  AtSymbolIcon,
  KeyIcon,
  ExclamationCircleIcon,
} from '@heroicons/react/24/outline';
import { ArrowRightIcon } from '@heroicons/react/20/solid';
import { Button } from './button';
import { signIn } from "next-auth/react";
import { useSearchParams } from 'next/navigation';
import { useState } from "react";

export default function LoginForm() {

  const searchParams = useSearchParams();
  const [errorMessage, setErrorMessage] = useState("");
  const [isPending, setIsPending] = useState(false);
  const callbackUrl = searchParams.get('callbackUrl') || '/dashboard';

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    
    event.preventDefault();
    setIsPending(true);
    setErrorMessage("");
   
    const formData = new FormData(event.currentTarget);
    const username = formData.get("username") as string;
    const password = formData.get("password") as string;
    
    
    try {
     
      const result = await signIn("credentials", {
        redirect: false,
        username,
        password,
      });
  
      if (result?.error) {
        setErrorMessage("Invalid credentials. Please try again.");
      } else {
        // Redirect only if login is successful
        window.location.href = callbackUrl;
      }
    } catch (error) {
      setErrorMessage("An unexpected error occurred.");
    } finally {
      setIsPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <div className="flex-1 rounded-lg bg-gray-50 px-6 pb-4 pt-8">
        <h1 className={`${lusitana.className} mb-3 text-2xl`}>
          Please log in.
        </h1>
        <div className="w-full">
          <div>
            <label
              className="mb-3 mt-5 block text-xs font-medium text-gray-900"
              htmlFor="username"
            >
              Username
            </label>
            <div className="relative">
              <input
                className="peer block w-full rounded-md border border-gray-200 py-[9px] pl-10 text-sm outline-2 placeholder:text-gray-500"
                id="username"
                type="username"
                name="username"
                placeholder="Enter your username"
                required
              />
              <AtSymbolIcon className="pointer-events-none absolute left-3 top-1/2 h-[18px] w-[18px] -translate-y-1/2 text-gray-500 peer-focus:text-gray-900" />
            </div>
          </div>
          <div className="mt-4">
            <label
              className="mb-3 mt-5 block text-xs font-medium text-gray-900"
              htmlFor="password"
            >
              Password
            </label>
            <div className="relative">
              <input
                className="peer block w-full rounded-md border border-gray-200 py-[9px] pl-10 text-sm outline-2 placeholder:text-gray-500"
                id="password"
                type="password"
                name="password"
                placeholder="Enter password"
                required
              />
              <KeyIcon className="pointer-events-none absolute left-3 top-1/2 h-[18px] w-[18px] -translate-y-1/2 text-gray-500 peer-focus:text-gray-900" />
            </div>
          </div>
        </div>
        <input type="hidden" name="redirectTo" value={callbackUrl} />
        <Button type="submit" className="mt-4 w-full" disabled={isPending}>
          {isPending ? "Logging in..." : "Log in"} <ArrowRightIcon className="ml-auto h-5 w-5 text-gray-50" />
        </Button>
        <div className="flex h-8 items-end space-x-1">
        {errorMessage && (
            <>
              <ExclamationCircleIcon className="h-5 w-5 text-red-500" />
              <p className="text-sm text-red-500">{errorMessage}</p>
            </>
          )}
        </div>
      </div>
    </form>
  );
}

