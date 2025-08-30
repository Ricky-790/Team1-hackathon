import { useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";

type Species = "Dog" | "Cat";
type Accessory = "Hat" | "Chain";

const speciesOptions: Species[] = ["Dog", "Cat"];
const accessoriesOptions: Accessory[] = ["Hat", "Chain"];

export default function PetCustomizer() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [species, setSpecies] = useState<Species>("Dog");
  const [color, setColor] = useState<string>("#ffcc00");
  const [accessories, setAccessories] = useState<Accessory[]>([]);
  
  const baseImages: Record<Species, string> = {
    Dog: "/assets/dog.png",
    Cat: "/assets/cat.png",
  };

  const accessoryImages: Record<Accessory, string> = {
    Hat: "/assets/hat.png",
    Chain: "/assets/chain.png",
  };

  // Draw the pet on canvas whenever the state changes
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const width = 300;
    const height = 300;
    canvas.width = width;
    canvas.height = height;

    ctx.clearRect(0, 0, width, height);

    const baseImg = new Image();
    baseImg.crossOrigin = "anonymous";
    baseImg.src = baseImages[species];

    baseImg.onload = () => {
      // Draw base image
      ctx.drawImage(baseImg, 0, 0, width, height);

      // Apply color overlay
      ctx.globalCompositeOperation = "source-atop";
      ctx.fillStyle = color;
      ctx.fillRect(0, 0, width, height);
      ctx.globalCompositeOperation = "source-over";

      // Draw accessories
      accessories.forEach((acc) => {
        const accImg = new Image();
        accImg.crossOrigin = "anonymous";
        accImg.src = accessoryImages[acc];
        accImg.onload = () => ctx.drawImage(accImg, 0, 0, width, height);
      });
    };
  }, [species, color, accessories]);

  const handleAccessoryChange = (acc: Accessory) => {
    setAccessories((prev) =>
      prev.includes(acc)
        ? prev.filter((a) => a !== acc)
        : [...prev, acc]
    );
  };

  const downloadImage = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const link = document.createElement("a");
    link.download = "custom-pet.png";
    link.href = canvas.toDataURL("image/png");
    link.click();
  };

  return (
    <div className="flex flex-col items-center min-h-screen bg-gray-100 p-6">
      <h1 className="text-3xl font-bold mb-4">Create Your Pixel Pet</h1>

      {/* Animated Preview */}
      <motion.div
        className="mb-6"
        animate={{ y: [0, -5, 0] }}
        transition={{ duration: 1, repeat: Infinity }}
      >
        <motion.img
          src={baseImages[species]}
          alt="Pet"
          className="w-48 h-48 mx-auto"
          style={{ filter: "drop-shadow(2px 2px 2px #888)" }}
          animate={{ rotate: [0, 3, -3, 0] }}
          transition={{ duration: 1.2, repeat: Infinity }}
        />
      </motion.div>

      <div className="bg-white rounded-lg shadow-md p-4 w-full max-w-md mb-6">
        {/* Species Selector */}
        <label className="block font-semibold mb-2">Species:</label>
        <select
          value={species}
          onChange={(e) => setSpecies(e.target.value as Species)}
          className="border rounded p-2 mb-4 w-full"
        >
          {speciesOptions.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </select>

        {/* Color Picker */}
        <label className="block font-semibold mb-2">Body Color:</label>
        <input
          type="color"
          value={color}
          onChange={(e) => setColor(e.target.value)}
          className="mb-4 w-16 h-10 border rounded"
        />

        {/* Accessories */}
        <label className="block font-semibold mb-2">Accessories:</label>
        <div className="flex gap-4 mb-4">
          {accessoriesOptions.map((acc) => (
            <label key={acc} className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={accessories.includes(acc)}
                onChange={() => handleAccessoryChange(acc)}
              />
              {acc}
            </label>
          ))}
        </div>

        <button
          onClick={downloadImage}
          className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
        >
          Download Pet
        </button>
      </div>

      {/* Hidden Canvas */}
      <canvas ref={canvasRef} style={{ display: "none" }}></canvas>
    </div>
  );
}
