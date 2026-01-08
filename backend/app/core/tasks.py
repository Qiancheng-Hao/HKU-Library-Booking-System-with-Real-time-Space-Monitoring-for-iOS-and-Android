from datetime import datetime, date
from sqlalchemy import select, or_, and_
from app.core.database import SessionLocal
from app.models import Reservation, ReservationStatus
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def update_expired_reservations():
    """
    Background task to mark past confirmed reservations as finished.
    """
    db = SessionLocal()
    try:
        now = datetime.now()
        today = date.today()
        current_time = now.time()

        # Find all confirmed reservations that have passed
        stmt = (
            select(Reservation)
            .where(
                Reservation.status == ReservationStatus.confirmed,
                or_(
                    Reservation.reservation_date < today,
                    and_(
                        Reservation.reservation_date == today,
                        Reservation.end_time < current_time,
                    ),
                ),
            )
        )
        
        expired_reservations = db.execute(stmt).scalars().all()
        
        if expired_reservations:
            count = 0
            for res in expired_reservations:
                res.status = ReservationStatus.finished
                db.add(res)
                count += 1
            
            db.commit()
            logger.info(f"Updated {count} expired reservations to 'finished'.")
        else:
            logger.info("No expired reservations to update.")
    except Exception as e:
        logger.error(f"Error updating expired reservations: {e}")
        db.rollback()
    finally:
        db.close()
