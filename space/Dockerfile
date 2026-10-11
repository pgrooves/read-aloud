FROM node:22-slim

# Hugging Face Spaces run the container as user 1000
USER node
ENV HOME=/home/node NODE_ENV=production PORT=7860
WORKDIR /home/node/app

COPY --chown=node package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

COPY --chown=node server.js ./
# Download the voice model at build time so the server starts quickly
RUN node -e "import('kokoro-js').then(({ KokoroTTS }) => KokoroTTS.from_pretrained('onnx-community/Kokoro-82M-v1.0-ONNX', { dtype: process.env.DTYPE || 'fp32', device: 'cpu' }))"

EXPOSE 7860
CMD ["node", "server.js"]
