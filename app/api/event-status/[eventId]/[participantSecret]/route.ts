import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';

export async function GET(
  request: Request,
  { params }: { params: { eventId: string; participantSecret: string } }
) {
  try {
    const { eventId, participantSecret } = params;
    if (!eventId || !participantSecret) {
      return NextResponse.json({ message: 'Event ID and Participant Secret are required.' }, { status: 400 });
    }

    const eventData = await prisma.bailEvent.findUnique({
      where: { id: eventId },
      include: {
        participants: {
          select: {
            name: true,
            wantsToBail: true,
            secret: true,
          }
        }
      },
    });

    if (!eventData) {
      return NextResponse.json({ message: 'Bailout plan not found or expired.' }, { status: 404 });
    }
    
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    if (eventData.createdAt < sevenDaysAgo) {
        return NextResponse.json({ message: 'Bailout plan has expired.' }, { status: 404 });
    }

    const currentParticipant = eventData.participants.find(p => p.secret === participantSecret);
    if (!currentParticipant) {
      return NextResponse.json({ message: 'Invalid participant for this event.' }, { status: 403 });
    }

    const publicEventData = {
      id: eventData.id,
      description: eventData.description,
      status: eventData.status,
      participants: eventData.participants.map(p => ({
        name: p.name,
        wantsToBail: p.wantsToBail,
        isCurrentUser: p.secret === participantSecret,
      })),
      currentUser: {
         name: currentParticipant.name,
         wantsToBail: currentParticipant.wantsToBail
      }
    };

    return NextResponse.json(publicEventData, { status: 200 });
  } catch (error) {
    console.error('Error fetching event status:', error);
    return NextResponse.json({ message: 'Internal server error.' }, { status: 500 });
  }
}
