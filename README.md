# Mutual Bail

Mutual Bail is a web application that allows users to create, share, and track "bail" events—collaborative commitments where participants can support each other in achieving goals or holding each other accountable. The app is built with Next.js, TypeScript, Tailwind CSS, and Prisma.

![Mutual Bail Screencap](./screencap.gif)

## Features

- Create a new bail event and invite participants
- Share event links easily
- Track the status of each participant
- Celebrate successful events with confetti effects
- Responsive and modern UI

## Tech Stack

- [Next.js](https://nextjs.org/)
- [TypeScript](https://www.typescriptlang.org/)
- [Tailwind CSS](https://tailwindcss.com/)
- [Prisma ORM](https://www.prisma.io/)
- [SQLite](https://www.sqlite.org/) (default for development)
- [React Confetti](https://www.npmjs.com/package/react-confetti)

## Getting Started

### Prerequisites

- Node.js (v18+ recommended)
- [Bun](https://bun.sh/) (if using Bun, otherwise use npm/yarn)
- [Prisma CLI](https://www.prisma.io/docs/reference/api-reference/command-reference)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/mutual-bail.git
   cd mutual-bail
   ```

2. Install dependencies:

   ```bash
   bun install
   # or
   npm install
   ```

3. Set up the database:

   ```bash
   npx prisma migrate dev --name init
   ```

4. Start the development server:

   ```bash
   bun run dev
   # or
   npm run dev
   ```

5. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

- `app/` - Next.js app directory (routes, API endpoints, pages)
- `components/` - React components
- `lib/` - Utility libraries (e.g., Prisma client)
- `prisma/` - Prisma schema and migrations
- `public/` - Static assets

## Development

- Edit the Prisma schema in `prisma/schema.prisma` and run `npx prisma migrate dev` to update the database.
- Add new API routes in `app/api/`.
- Add or update UI components in `components/`.

## License

MIT

---

Feel free to contribute or open issues for suggestions and bug reports!
