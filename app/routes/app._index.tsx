import type { LoaderFunctionArgs } from "@remix-run/node";
import { authenticate } from "~/shopify.server";

export const loader = async ({ request }: LoaderFunctionArgs) => {
  await authenticate.admin(request);
  return null;
};

export default function Index() {
  return (
    <div style={{ padding: "2rem", fontFamily: "sans-serif" }}>
      <h1>👋 Hello World!</h1>
      <p>Your Shopify DB Integration app is working.</p>
    </div>
  );
}
