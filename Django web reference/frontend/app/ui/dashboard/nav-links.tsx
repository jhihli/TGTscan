"use client"
import {
  UserGroupIcon,
  HomeIcon,
  DocumentDuplicateIcon,
} from '@heroicons/react/24/outline';
import { useSession } from "next-auth/react";

const links = [
  { name: 'Product', href: '/dashboard', icon: HomeIcon },
  { name: 'SO', href: '/dashboard/so', icon: DocumentDuplicateIcon },
];

export default function NavLinks() {

  const { data: session, status  } = useSession();
  const userRole = session?.user?.role;
  
  return (
    <>
      {links
        //Filter diff users see diff nav-pages
        .filter((link) => {
          if (link.name === 'Product') return true;
          if (link.name === 'SO') return userRole === 'admin' || userRole === 'manager';
          return userRole === 'admin';
        })
        .map((link) => {

          const LinkIcon = link.icon;
          return (
            <a
              key={link.name}
              href={link.href}
              className="flex h-[48px] grow items-center justify-center gap-2 rounded-md bg-gray-50 p-3 text-sm font-medium hover:bg-sky-100 hover:text-blue-600 md:flex-none md:justify-start md:p-2 md:px-3"
            >
              <LinkIcon className="w-6" />
              <p className="hidden md:block">{link.name}</p>
            </a>
          );
        })}
    </>
  );
}
