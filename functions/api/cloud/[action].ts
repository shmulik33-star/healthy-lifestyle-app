import { handleCloud } from '../../_shared/appwrite-cloud.mjs';

export async function onRequest(context: any) {
  return handleCloud(context.request, context.env, context.params.action);
}
