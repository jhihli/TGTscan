"use server"
import { Product } from "@/interface/IDatatable"
import { User } from "@/interface/IDatatable"


export async function getProducts(): Promise<Product[]> {
    const API_URL = process.env.NEXT_PUBLIC_Django_API_URL;

    if (!API_URL) {
        console.error("API URL is not set!");
        return [];
    }


    try {
        const response = await fetch(`${API_URL}/product/products`, {
            method: "GET",
            headers: {
                "Content-Type": "application/json",

            },
        });


        if (!response.ok) {
            throw new Error(`Error: ${response.status} - ${response.statusText} -  ${response.json}`);
        }

        const data = await response.json();

        return data; // Ensure that the backend response structure matches
    } catch (error) {
        console.error("Unexpected error:", error);
        return [];
    }
}


export async function getUser(): Promise<User[]> {
    const API_URL = process.env.NEXT_PUBLIC_Django_API_URL;

    if (!API_URL) {
        console.error("API URL is not set!");
        return [];
    }


    try {
        const response = await fetch(`${API_URL}/product/products`, {
            method: "GET",
            headers: {
                "Content-Type": "application/json",

            },
        });


        if (!response.ok) {
            throw new Error(`Error: ${response.status} - ${response.statusText} -  ${response.json}`);
        }

        const data = await response.json();

        return data; // Ensure that the backend response structure matches
    } catch (error) {
        console.error("Unexpected error:", error);
        return [];
    }
}
