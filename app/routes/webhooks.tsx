import { authenticate } from "~/shopify.server";
import type { ActionFunctionArgs } from "@remix-run/node";

console.log("[webhooks.tsx] module loading...");

export const action = async ({ request }: ActionFunctionArgs) => {
  console.log("[webhooks.tsx] action called, verifying webhook...");
  const { topic, shop, payload } = await authenticate.webhook(request);
  console.log(`[webhooks.tsx] webhook verified: topic=${topic}, shop=${shop}`);

  // Webhook handling is primarily done by the backend service.
  // This route handles any webhooks registered to the frontend URL.
  switch (topic) {
    case "APP_UNINSTALLED":
      console.log(`App uninstalled from ${shop}`);
      break;
    default:
      console.log(`Unhandled webhook topic: ${topic}`);
  }

  return new Response(null, { status: 200 });
};
