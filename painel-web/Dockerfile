# ---------- build ----------
FROM node:20-bookworm AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# URL da API injetada no build (Vite). Vem do compose (build args).
ARG VITE_API_BASE
ENV VITE_API_BASE=$VITE_API_BASE
RUN npm run build

# ---------- runtime (nginx) ----------
FROM nginx:alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
