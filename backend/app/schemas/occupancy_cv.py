from pydantic import BaseModel


class OccupancyEstimateResponse(BaseModel):
    time_stamp: str
    location: str
    area: str
    total_number_of_person: int
    total_number_of_hogging_items: int
    total_number_of_seats: int
    occupancy_rate: float

