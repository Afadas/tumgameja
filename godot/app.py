import cv2
import mediapipe as mp
import socket
import json
import time
import sys
import math


class HandTracker:
  def __init__(self, host='127.0.0.1', port=10000):
    print(f"Initializing hand tracker to send data to {host}:{port}")

    # Initialize MediaPipe
    self.mp_hands = mp.solutions.hands
    self.hands = self.mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=1,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    )

    # Initialize socket connection to Godot
    try:
      self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
      self.server_address = (host, port)
      print(f"UDP socket created successfully")
    except socket.error as e:
      print(f"Socket creation error: {e}")
      sys.exit(1)

    # Camera setup
    self.cap = cv2.VideoCapture(0)
    if not self.cap.isOpened():
      print("Error: Could not open camera.")
      sys.exit(1)

    print("Camera opened successfully")

    # Gesture tracking
    self.current_gesture = "open"  # Can be "open", "fist", or "drag"
    self.previous_gesture = "open"
    self.drag_active = False
    self.drag_start_position = None  # Store position where drag began

    # Debug info
    self.last_send_time = time.time()
    self.frames_processed = 0
    self.packets_sent = 0

  def start_tracking(self):
    print("Starting hand tracking...")

    while self.cap.isOpened():
      success, image = self.cap.read()
      if not success:
        print("Failed to get frame from camera")
        continue

      self.frames_processed += 1

      # Flip the image horizontally for a more intuitive mirror view
      image = cv2.flip(image, 1)

      # Convert the BGR image to RGB
      image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

      # Process the image and find hands
      results = self.hands.process(image_rgb)

      # Send data at a reasonable frequency
      if time.time() - self.last_send_time > 0.01:  # ~30fps
        if results.multi_hand_landmarks:
          for hand_landmarks in results.multi_hand_landmarks:
            # Process hand landmarks
            hand_position, hand_gesture, tilt_angle, pull_distance = self._process_landmarks(hand_landmarks)

            # Update gesture state
            self._update_gesture_state(hand_position, hand_gesture)

            # Add movement controls to the position data
            hand_position['tilt_angle'] = tilt_angle
            hand_position['pull_distance'] = pull_distance

            # Send data to Godot
            self._send_to_godot(hand_position)

            # Draw landmarks for debugging
            self._draw_landmarks(image, hand_landmarks, tilt_angle, pull_distance)
        else:
          # Send neutral position when no hand is detected
          neutral_position = {
              'x': 0.5,
              'y': 0.5,
              'z': 0.5,
              'gesture': "open",
              'tilt_angle': 0,
              'pull_distance': 0
          }
          self._send_to_godot(neutral_position)
          self.current_gesture = "open"
          self.drag_active = False
          self.drag_start_position = None

        self.last_send_time = time.time()

      # Display stats on the image
      fps = self.frames_processed / (time.time() - self.last_send_time + 1)
      stats_text = f"FPS: {fps:.1f}, Packets: {self.packets_sent}"
      cv2.putText(image, stats_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

      # Display the image
      cv2.imshow('Hand Tracking', image)
      if cv2.waitKey(5) & 0xFF == 27:  # Press ESC to exit
        break

    # Clean up
    self.cap.release()
    cv2.destroyAllWindows()

  def _process_landmarks(self, hand_landmarks):
    # Get wrist position
    wrist = hand_landmarks.landmark[0]

    # Get index and pinky finger base for hand orientation
    index_base = hand_landmarks.landmark[5]  # Index finger MCP joint
    pinky_base = hand_landmarks.landmark[17]  # Pinky finger MCP joint

    # Get middle finger tip for pull detection
    middle_tip = hand_landmarks.landmark[12]  # Middle finger tip

    # Use the palm center as the main position
    palm_center = {
        'x': wrist.x,
        'y': wrist.y,
        'z': wrist.z
    }

    # Get fingertip positions for all fingers to detect fist
    thumb_tip = hand_landmarks.landmark[4]
    index_tip = hand_landmarks.landmark[8]
    ring_tip = hand_landmarks.landmark[16]
    pinky_tip = hand_landmarks.landmark[20]

    # Check for fist gesture by comparing distances
    # Calculate distances from thumb to each finger
    thumb_to_index = self._calculate_distance(thumb_tip, index_tip)
    thumb_to_middle = self._calculate_distance(thumb_tip, middle_tip)
    thumb_to_ring = self._calculate_distance(thumb_tip, ring_tip)
    thumb_to_pinky = self._calculate_distance(thumb_tip, pinky_tip)

    # Average these distances - lower number means fingers are closer together (fist)
    avg_distance = (thumb_to_index + thumb_to_middle + thumb_to_ring + thumb_to_pinky) / 4

    # Determine if hand is making fist gesture
    is_fist = avg_distance < 0.1  # Threshold can be adjusted

    # Determine hand gesture based on finger positions
    hand_gesture = "fist" if is_fist else "open"

    # Calculate tilt angle (left/right) based on pinky and index MCPs
    # This gives us rotation around the Y axis
    dy = index_tip.x - index_base.x
    dx = index_tip.y - index_base.y
    dx *= -1
    tilt_angle = math.degrees(math.atan2(dy, dx))

    # Clamp tilt angle to the range -75 to 75 degrees
    tilt_angle = max(-75, min(75, tilt_angle))

    # Calculate pull distance (for drag mode)
    # This measures how far the hand has moved since starting the drag
    pull_distance = 0.0
    if self.drag_active and self.drag_start_position:
      # Calculate 3D distance from drag start to current position
      dx = self.drag_start_position['x'] - palm_center['x']
      dy = self.drag_start_position['y'] - palm_center['y']
      dz = self.drag_start_position['z'] - palm_center['z']

      # Compute pull distance (normalized to 0-1 range)
      raw_distance = math.sqrt(dx * dx + dy * dy + dz * dz)
      pull_distance = min(1.0, raw_distance * 5)  # Scale factor can be adjusted

    return palm_center, hand_gesture, tilt_angle, pull_distance

  def _update_gesture_state(self, hand_position, hand_gesture):
    self.previous_gesture = self.current_gesture

    # Track when hand transitions from open to fist
    if (self.previous_gesture == "open" and
        hand_gesture == "fist" and
            not self.drag_active):

      self.current_gesture = "drag"
      self.drag_active = True
      # Store current position as drag start position
      self.drag_start_position = {
          'x': hand_position['x'],
          'y': hand_position['y'],
          'z': hand_position['z']
      }

    # Keep drag active as long as hand stays as fist
    elif self.current_gesture == "drag":
      if hand_gesture != "fist":
        self.current_gesture = hand_gesture
        self.drag_active = False
        self.drag_start_position = None
    else:
      self.current_gesture = hand_gesture

    # Update the hand position with gesture information
    hand_position['gesture'] = self.current_gesture

  def _calculate_distance(self, point1, point2):
    return ((point1.x - point2.x)**2 +
            (point1.y - point2.y)**2 +
            (point1.z - point2.z)**2)**0.5

  def _send_to_godot(self, position):
    try:
      data = json.dumps(position).encode('utf-8')
      self.sock.sendto(data, self.server_address)
      self.packets_sent += 1

      if self.packets_sent % 100 == 0:
        print(f"Sent {self.packets_sent} packets. Position: {position}, Gesture: {self.current_gesture}")
    except Exception as e:
      print(f"Error sending data: {e}")

  def _draw_landmarks(self, image, hand_landmarks, tilt_angle, pull_distance):
    # Draw hand skeleton
    mp_drawing = mp.solutions.drawing_utils
    mp_drawing.draw_landmarks(
        image,
        hand_landmarks,
        self.mp_hands.HAND_CONNECTIONS
    )

    # Overlay gesture status
    color_map = {
        "open": (0, 255, 0),
        "fist": (0, 0, 255),
        "drag": (255, 0, 0)
    }

    status_text = f"GESTURE: {self.current_gesture.upper()}"
    status_color = color_map.get(self.current_gesture, (255, 255, 255))
    cv2.putText(image, status_text, (10, 70), cv2.FONT_HERSHEY_SIMPLEX, 1, status_color, 2)

    # Add tilt and pull info
    tilt_text = f"TILT: {tilt_angle:.1f} deg"
    tilt_color = (0, 255, 255)
    cv2.putText(image, tilt_text, (10, 110), cv2.FONT_HERSHEY_SIMPLEX, 1, tilt_color, 2)

    pull_text = f"PULL: {pull_distance:.2f}"
    pull_color = (255, 255, 0)
    cv2.putText(image, pull_text, (10, 150), cv2.FONT_HERSHEY_SIMPLEX, 1, pull_color, 2)


if __name__ == "__main__":
  # Allow command line override of host and port
  host = '127.0.0.1'
  port = 10000

  if len(sys.argv) > 1:
    host = sys.argv[1]
  if len(sys.argv) > 2:
    port = int(sys.argv[2])

  print(f"Starting hand tracker sending to {host}:{port}")
  tracker = HandTracker(host, port)

  try:
    tracker.start_tracking()
  except KeyboardInterrupt:
    print("Tracking stopped by user")
  except Exception as e:
    print(f"Error during tracking: {e}")
