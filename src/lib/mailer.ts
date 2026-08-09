import nodemailer from "nodemailer";
import { getEnv } from "./env";

let transporter: ReturnType<typeof nodemailer.createTransport> | null = null;

function getTransporter() {
  const env = getEnv();
  if (!env.MAIL_ENABLED) return null;
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: env.SMTP_HOST,
      port: env.SMTP_PORT,
      secure: env.SMTP_PORT === 465,
      auth: { user: env.SMTP_USER, pass: env.SMTP_PASSWORD },
    });
  }
  return transporter;
}

export async function sendMail(opts: { to: string; subject: string; text: string }) {
  const env = getEnv();
  const t = getTransporter();
  if (!t) {
    console.log(`[mail:disabled] to=${opts.to} subject="${opts.subject}"\n${opts.text}`);
    return;
  }
  await t.sendMail({ from: env.MAIL_FROM, to: opts.to, subject: opts.subject, text: opts.text });
}
