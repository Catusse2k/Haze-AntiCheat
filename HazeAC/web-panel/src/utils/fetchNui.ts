/**
 * fetchNui - Utility for FiveM NUI communication
 * This is a standalone implementation compatible with any framework
 */

/**
 * Fetch data from FiveM server via NUI callback
 * @param eventName - The event name to trigger on server
 * @param data - Optional data to send with the event
 * @returns Promise with the response from server
 */
export const fetchNui = async <T = any>(eventName: string, data: any = {}): Promise<T> => {
  try {
    const response = await fetch(`https://cfx-nui-${eventName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify(data),
    });

    if (!response.ok) {
      throw new Error(`NUI callback failed: ${response.statusText}`);
    }

    const result = await response.json();
    return result as T;
  } catch (error) {
    console.error(`NUI callback error (${eventName}):`, error);
    throw error;
  }
};

/**
 * Send data to FiveM server without waiting for response
 * @param eventName - The event name to trigger
 * @param data - Optional data to send
 */
export const sendNui = (eventName: string, data: any = {}): void => {
  try {
    fetch(`https://cfx-nui-${eventName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: JSON.stringify(data),
    }).catch((error) => {
      console.error(`NUI send error (${eventName}):`, error);
    });
  } catch (error) {
    console.error(`NUI send error (${eventName}):`, error);
  }
};
