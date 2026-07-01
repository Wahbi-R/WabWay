The Android-share-intent intake screen — appears when a person shares a link/file into Wabway from Instagram, Google Maps, Gmail, Files, etc. Suggests a destination (Spot / Link / Travel doc / Receipt) based on detected content type.

```jsx
<IncomingShareCard detectedLabel="Instagram link" tripName="Japan, November"
  destinationOptions={[{value:'spot',label:'Spot / place idea'},{value:'link',label:'General link'},{value:'note',label:'Itinerary note'}]} />
```
