using CSFML, CSFML.LibCSFML

include("audio.jl")

const scaleFactor = 4.0

sfColor(val::UInt32) = CSFML.sfColor(((val >> 16) & 0xFF) % UInt8, ((val >> 8) & 0xFF) % UInt8, (val & 0xFF) % UInt8, 0xFF)

function window(name::String, engine)

  game = engine.loadgame(name)

  texture = sfTexture_create(256, 240)
  @assert texture != C_NULL

  sprite = sfSprite_create()
  sfSprite_setTexture(sprite, texture, sfTrue)
  sfSprite_setScale(sprite, sfVector2f(scaleFactor, scaleFactor))

  image = sfImage_create(256, 240)

  mode = sfVideoMode(Int(256 * scaleFactor), Int(240 * scaleFactor), 32)

  window = sfRenderWindow_create(mode, name, sfResize | sfClose, C_NULL)
  @assert window != C_NULL
  sfWindow_setFramerateLimit(window, 60)
  updatescreen!(window, texture, image, sprite, engine, game)

  previousSound = C_NULL
  previousBuffer = C_NULL

  event_ref = Ref(sfEvent(sfEvtClosed, ntuple(_ -> UInt32(0), 20)))

  starttime = time()
  totalticks = 0
  while Bool(sfRenderWindow_isOpen(window))
    # process events
    while Bool(sfRenderWindow_pollEvent(window, event_ref))
      # close window : exit
      if event_ref.x.type == sfEvtClosed
        sfRenderWindow_close(window)
      end
    end
    # Read input
    input = readinput()
    engine.setbuttons1!(game, input)

    # Step a single frame
    totalticks += engine.stepframe!(game)

    # Play audio.
    samples = engine.audiosamples(game)
    currentBuffer = sfSoundBuffer_createFromSamples(samples, length(samples), 1, 44100)
    currentSound = sfSound_create()
    sfSound_setBuffer(currentSound, currentBuffer)
    sfSound_play(currentSound)

    # Render the screen
    updatescreen!(window, texture, image, sprite, engine, game)

    # Swap out sound buffers
    sfSound_destroy(previousSound)
    sfSoundBuffer_destroy(previousBuffer)
    previousSound = currentSound
    previousBuffer = currentBuffer
  end

  sfSound_destroy(previousSound)
  sfSoundBuffer_destroy(previousBuffer)
  sfSprite_destroy(sprite)
  sfTexture_destroy(texture)
  sfRenderWindow_destroy(window)
end

function updatescreen!(window, texture, image, sprite, engine, game)
    s = engine.screen(game)
    for i = 1:256, j = 1:240
      color = sfColor(s[j, i].color)
      sfImage_setPixel(image, i-1, j-1, color)
    end
    sfTexture_updateFromImage(texture, image, 0, 0)
    # draw the sprite
    sfRenderWindow_drawSprite(window, sprite, C_NULL)
    # update the window
    sfRenderWindow_display(window)
end

function readinput()
  input = 0x00
  if Bool(sfKeyboard_isKeyPressed(sfKeyC))
    input |= 0x01
  end
  if Bool(sfKeyboard_isKeyPressed(sfKeyX))
    input |= 0x02
  end
  if Bool(sfKeyboard_isKeyPressed(sfKeyTab))
    input |= 0x04
  end
  if Bool(sfKeyboard_isKeyPressed(sfKeyEnter))
    input |= 0x08
  end
  if Bool(sfKeyboard_isKeyPressed(sfKeyUp))
    input |= 0x10
  end
  if Bool(sfKeyboard_isKeyPressed(sfKeyDown))
    input |= 0x20
  end
  if Bool(sfKeyboard_isKeyPressed(sfKeyLeft))
    input |= 0x40
  end
  if Bool(sfKeyboard_isKeyPressed(sfKeyRight))
    input |= 0x80
  end
  input
end
