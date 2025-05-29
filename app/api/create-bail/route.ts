import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';
import { v4 as uuidv4 } from 'uuid';

export async function POST(request: Request) {
  try {
    const { description, numParticipants = 2 } = await request.json();

    if (numParticipants < 2 || numParticipants > 5) {
      return NextResponse.json({ message: 'Number of participants must be between 2 and 5.' }, { status: 400 });
    }

    const participantSecrets: { name: string, secret: string }[] = [];
    for (let i = 0; i < numParticipants; i++) {
      participantSecrets.push({
        secret: uuidv4(),
        name: `Participant ${i + 1}`,
      });
    }

    const newEvent = await prisma.bailEvent.create({
      data: {
        description: description || 'A secret plan',
        status: 'active',
        numRequired: numParticipants,
        participants: {
          create: participantSecrets.map(p => ({
            secret: p.secret,
            name: p.name,
            wantsToBail: false,
          })),
        },
      },
      include: {
        participants: true,
      },
    });

    const baseUrl = process.env.NEXT_PUBLIC_BASE_URL || 'http://localhost:3000';
    const participantLinks = newEvent.participants.map(p => ({
      name: p.name,
      secret: p.secret,
      link: `${baseUrl}/bail/${newEvent.id}/${p.secret}`,
    }));

    return NextResponse.json({ eventId: newEvent.id, participantLinks }, { status: 201 });
  } catch (error) {
    console.error('Error creating bail event:', error);
    return NextResponse.json({ message: 'Internal server error.' }, { status: 500 });
  }
}
