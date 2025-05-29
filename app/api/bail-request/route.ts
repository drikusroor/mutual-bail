import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';

export async function POST(request: Request) {
  try {
    const { eventId, participantSecret } = await request.json();

    if (!eventId || !participantSecret) {
      return NextResponse.json({ message: 'Event ID and Participant Secret are required.' }, { status: 400 });
    }

    const resultEvent = await prisma.$transaction(async (tx) => {
      const event = await tx.bailEvent.findUnique({
        where: { id: eventId },
        include: { participants: true },
      });

      if (!event) {
        throw new Error('Bailout plan not found or expired.');
      }

      if (event.status === 'cancelled') {
        return event;
      }

      const participantToUpdate = event.participants.find(p => p.secret === participantSecret);

      if (!participantToUpdate) {
        throw new Error('Invalid participant for this event.');
      }

      if (participantToUpdate.wantsToBail) {
        return event;
      }

      await tx.participant.update({
        where: { id: participantToUpdate.id },
        data: { wantsToBail: true },
      });

      const updatedParticipants = await tx.participant.findMany({
        where: { bailEventId: eventId }
      });

      const allBailed = updatedParticipants.every(p => p.wantsToBail);

      let finalEvent = event;
      if (allBailed) {
        finalEvent = await tx.bailEvent.update({
          where: { id: eventId },
          data: { status: 'cancelled' },
          include: { participants: true },
        });
      } else {
        finalEvent = await tx.bailEvent.findUnique({
            where: { id: eventId },
            include: { participants: true }
        });
        if (!finalEvent) throw new Error("Event disappeared post-participant update");
      }
      return finalEvent;
    });

    const currentParticipantForResponse = resultEvent.participants.find(p => p.secret === participantSecret);
    const publicEventData = {
      id: resultEvent.id,
      description: resultEvent.description,
      status: resultEvent.status,
      participants: resultEvent.participants.map(p => ({
        name: p.name,
        wantsToBail: p.wantsToBail,
        isCurrentUser: p.secret === participantSecret,
      })),
      currentUser: currentParticipantForResponse ? {
         name: currentParticipantForResponse.name,
         wantsToBail: currentParticipantForResponse.wantsToBail
      } : null
    };

    const message = resultEvent.status === 'cancelled' ? 'Plans cancelled! Everyone bailed.'
                  : publicEventData.currentUser?.wantsToBail ? 'Your bail request is registered.'
                  : 'Bail request updated.';

    return NextResponse.json({ message, event: publicEventData }, { status: 200 });

  } catch (error: any) {
    console.error('Error processing bail request:', error);
    if (error.message === 'Bailout plan not found or expired.' || error.message === 'Invalid participant for this event.') {
        return NextResponse.json({ message: error.message }, { status: 404 });
    }
    return NextResponse.json({ message: 'Internal server error.' }, { status: 500 });
  }
}
