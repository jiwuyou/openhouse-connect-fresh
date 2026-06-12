export interface BridgeImageAttachment {
  data: string;
  mime_type: string;
  file_name?: string;
}

export interface BridgeFileAttachment {
  data: string;
  mime_type: string;
  file_name: string;
}

export interface BridgeAudioAttachment {
  data: string;
  mime_type: string;
  format: string;
  duration?: number;
  file_name?: string;
}

export interface BridgeAttachmentPayload {
  images?: BridgeImageAttachment[];
  files?: BridgeFileAttachment[];
  audio?: BridgeAudioAttachment | null;
}

export type BridgeArtifact = Record<string, unknown>;
export type BridgeMetadata = Record<string, unknown>;
